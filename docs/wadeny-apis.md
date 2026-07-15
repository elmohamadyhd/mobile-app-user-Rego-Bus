# Wadeny API Reference (v1)

> Generated from [`Wadeny.postman_collection.json`](Wadeny.postman_collection.json)

## Overview

| Property | Value |
|----------|-------|
| **Base URL** | `https://demo.safaria.travel/api/v1` |
| **Collection** | Wadeny |
| **Default auth** | Bearer token (`{{token}}`) |
| **Content-Type** | `application/json` (most endpoints) |
| **Total requests** | 65 |
| **Documented saved responses** | 67 |

Public endpoints (no auth): Auth group (login, register, OTP, password reset) and most Content endpoints.

### Localization

Every request must include `Accept-Language: ar` or `Accept-Language: en`.

The value matches the user's active app locale (Settings or device default, via `LocaleController`). REGO mobile attaches this header automatically on **all** Dio API calls.

The backend uses it to localize `message`, `errors`, and localized content in responses. Supported values: `ar` (primary), `en`.

## Quick reference (unique endpoints)

| Method | Path | Example name |
|--------|------|--------------|
| `DELETE` | `/profile` | Delete account |
| `DELETE` | `/profile/address-book/12` | Delete |
| `DELETE` | `/profile/notifications` | Delete |
| `GET` | `/banners` | Banners list |
| `GET` | `/buses/carriers` | Carriers |
| `GET` | `/buses/locations` | Locations |
| `GET` | `/buses/stations` | Stations |
| `GET` | `/buses/trips` | Search trips |
| `GET` | `/buses/trips/236510` | Search details |
| `GET` | `/buses/trips/236510/seats` | Seats |
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
| `GET` | `/profile/buses/orders` | List |
| `GET` | `/profile/buses/orders/:id` | Show |
| `GET` | `/profile/flights/orders` | List |
| `GET` | `/profile/flights/orders/:id` | Show |
| `GET` | `/profile/notifications` | List |
| `GET` | `/profile/private/orders` | List |
| `GET` | `/profile/private/orders/:id` | Show |
| `GET` | `/profile/tickets` | Tickets list |
| `GET` | `/profile/tickets/10` | Show ticket |
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
| `POST` | `/buses/trips/236437/create-ticket` | Create Ticket |
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
| `PUT` | `/profile/address-book/22` | Update |
| `PUT` | `/profile/firebase/token` | Update Token |

## Table of contents

- [Auth](#auth) (8 requests)
- [Profile](#profile) (25 requests)
- [Content](#content) (12 requests)
- [Flights](#flights) (8 requests)
- [Private](#private) (3 requests)
- [Buses](#buses) (8 requests)
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
- All endpoints honor `Accept-Language`; Auth saved examples below show `ar` and `en` variants where captured in Postman.
- Success responses that return a session include `data.api_token` (Bearer token for subsequent calls).

### Login

| | |
|---|---|
| **Method** | `POST` |
| **Path** | `/auth/login` |
| **Full URL** | `https://demo.safaria.travel/api/v1/auth/login` |
| **Auth** | No (public) |

**Body (form-data):** `phonecode`, `mobile`, `password`

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |
| `Accept-Language` | `ar` \| `en` (app locale) |
| `Content-Type` | application/json |

**Saved responses:**

| HTTP | Scenario | Language | Error fields |
|------|----------|----------|--------------|
| `422` | Invalid credentials | ar | `credentials` |
| `400` | Mobile not registered | ar | `mobile` |
| `200` | Success — user data | ar | — |
| `200` | Success — user data | en | — |
| `422` | Invalid credentials | en | `credentials` |
| `400` | Mobile not registered | en | `mobile` |
| `200` | Success — OTP sent | en | — |

#### 422 — Invalid credentials (ar)

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

#### 200 — Success — user data (ar)

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

#### 200 — Success — OTP sent (en)

```json
{
  "status": 200,
  "message": "OTP code sent",
  "errors": {},
  "data": {},
  "need_verfication": true
}
```

### Register

| | |
|---|---|
| **Method** | `POST` |
| **Path** | `/auth/register` |
| **Full URL** | `https://demo.safaria.travel/api/v1/auth/register` |
| **Auth** | No (public) |

**Body (form-data):** `email`, `mobile`, `phonecode`, `name`, `password`, `password_confirmation`, `firebase_token`

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |
| `Accept-Language` | `ar` \| `en` (app locale) |

**Saved responses:**

| HTTP | Scenario | Language | Error fields |
|------|----------|----------|--------------|
| `400` | Email and mobile already taken (×2) | ar | `email`, `mobile` |
| `400` | Mobile not registered | ar | `mobile` |
| `200` | Success — OTP sent (×2) | ar | — |
| `400` | حقل firebase token مطلوب. | ar | `firebase_token` |

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

#### 400 — حقل firebase token مطلوب. (ar)

```json
{
  "status": 400,
  "message": "حقل firebase token مطلوب.",
  "errors": {
    "firebase_token": "حقل firebase token مطلوب."
  },
  "data": {}
}
```

### OTP Verification

| | |
|---|---|
| **Method** | `POST` |
| **Path** | `/auth/verify-otp` |
| **Full URL** | `https://demo.safaria.travel/api/v1/auth/verify-otp` |
| **Auth** | No (public) |

**Body (form-data):** `mobile`, `phonecode`, `code`

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |
| `Accept-Language` | `ar` \| `en` (app locale) |

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
| **Full URL** | `https://demo.safaria.travel/api/v1/auth/resend-otp` |
| **Auth** | No (public) |

**Body (form-data):** `mobile`, `phonecode`

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |
| `Accept-Language` | `ar` \| `en` (app locale) |
| `Content-Type` | application/json |

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
| **Full URL** | `https://demo.safaria.travel/api/v1/auth/send-otp` |
| **Auth** | No (public) |

**Body (form-data):** `mobile`, `phonecode`

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |
| `Accept-Language` | `ar` \| `en` (app locale) |
| `Content-Type` | application/json |

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
| **Full URL** | `https://demo.safaria.travel/api/v1/auth/validate-otp` |
| **Auth** | No (public) |

**Body (form-data):** `mobile`, `phonecode`, `code`

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |
| `Accept-Language` | `ar` \| `en` (app locale) |

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
| **Full URL** | `https://demo.safaria.travel/api/v1/auth/forget-password` |
| **Auth** | No (public) |

**Body (JSON):**

```json
{
  "mobile": 1276586027,
  "phonecode": 20
}
```

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |
| `Accept-Language` | `ar` \| `en` (app locale) |
| `Content-Type` | application/json |

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
| **Full URL** | `https://demo.safaria.travel/api/v1/auth/reset-password` |
| **Auth** | No (public) |

**Body (form-data):** `mobile`, `phonecode`, `code`, `password`, `password_confirmation`

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |
| `Accept-Language` | `ar` \| `en` (app locale) |
| `Content-Type` | application/json |

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
| 3 | `PUT` | `/profile/address-book/22` | Update |
| 4 | `DELETE` | `/profile/address-book/12` | Delete |
| 5 | `GET` | `/profile/notifications` | List |
| 6 | `DELETE` | `/profile/notifications` | Delete |
| 7 | `GET` | `/profile/tickets/6/replies` | List |
| 8 | `POST` | `/profile/tickets/6/replies` | Create |
| 9 | `GET` | `/profile/tickets` | Tickets list |
| 10 | `GET` | `/profile/tickets/10` | Show ticket |
| 11 | `POST` | `/profile/tickets` | Create Ticket |
| 12 | `GET` | `/profile/wallet` | List transactions |
| 13 | `POST` | `/profile/wallet/:amount/charge` | Charge |
| 14 | `GET` | `/profile/flights/orders` | List |
| 15 | `GET` | `/profile/flights/orders/:id` | Show |
| 16 | `GET` | `/profile/buses/orders` | List |
| 17 | `GET` | `/profile/buses/orders/:id` | Show |
| 18 | `GET` | `/profile/private/orders` | List |
| 19 | `GET` | `/profile/private/orders/:id` | Show |
| 20 | `GET` | `/profile` | Show profile |
| 21 | `POST` | `/profile` | Update profile |
| 22 | `PUT` | `/profile/firebase/token` | Update Token |
| 23 | `POST` | `/profile/verify-alt-phone` | Verify Alt phone |
| 24 | `POST` | `/profile/update-password` | Update password |
| 25 | `DELETE` | `/profile` | Delete account |

#### addresses

### List

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/profile/address-book` |
| **Full URL** | `https://demo.safaria.travel/api/v1/profile/address-book` |
| **Auth** | Bearer token required |
| **Folder** | addresses |

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |
| `Accept-Language` | `ar` \| `en` (app locale) |

**Saved responses:**

| HTTP | Scenario | Language | Error fields |
|------|----------|----------|--------------|
| `401` | Unauthenticated | ar | — |
| `200` | Empty results | ar | — |
| `200` | Customer addresses list | ar | — |

#### 401 — Unauthenticated (ar)

```json
{
  "status": 401,
  "message": "Unauthenticated",
  "errors": {},
  "data": {}
}
```

#### 200 — Empty results (ar)

```json
{
  "status": 200,
  "message": "Customer addresses list",
  "errors": {},
  "data": [],
  "pagination": {
    "total": 0,
    "lastPage": 1,
    "perPage": 15,
    "currentPage": 1,
    "nextPageUrl": null,
    "previousPageUrl": null
  }
}
```

#### 200 — Customer addresses list (ar)

```json
{
  "status": 200,
  "message": "Customer addresses list",
  "errors": {},
  "data": [
    {
      "id": 22,
      "city": null,
      "name": "محرب بيك",
      "phone": "1554052685",
      "notes": "Quasi quisquam tenetur sint quas. Fugit quisquam pariatur rerum. Nulla sit mollitia. Quis dolores dolore eligendi similique magnam numquam sint ea aliquid. Eveniet possimus vitae.",
      "whatsapp_share_link": "https://api.whatsapp.com/send?text=%E2%80%8F%E2%80%8Ehttps%3A%2F%2Fwww.google.com%2Fmaps%2Fdir%2F%3Fapi%3D1%26destination%3D24.2222%2C46.5555",
      "map_location": {
        "lat": 24.2222,
        "lng": 46.5555,
        "address_name": "محرم بيك شارع المطافي عماره عشره"
      }
    }
  ],
  "pagination": {
    "total": 1,
    "lastPage": 1,
    "perPage": 15,
    "currentPage": 1,
    "nextPageUrl": null,
    "previousPageUrl": null
  }
}
```

### Create

| | |
|---|---|
| **Method** | `POST` |
| **Path** | `/profile/address-book` |
| **Full URL** | `https://demo.safaria.travel/api/v1/profile/address-book` |
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
| `Accept-Language` | `ar` \| `en` (app locale) |

**Saved responses:**

| HTTP | Scenario | Language | Error fields |
|------|----------|----------|--------------|
| `200` | Created | ar | — |
| `400` | حقل الاسم مطلوب. (×3) | ar | `name`, `map_location`, `map_location.lat`, `map_location.lng`, `map_location.address_name` |
| `400` | حقل map location.lat مطلوب. | ar | `map_location.lat` |

#### 200 — Created (ar)

```json
{
  "status": 200,
  "message": "Created",
  "errors": {},
  "data": {
    "id": 22,
    "city": null,
    "name": "محرب بيك",
    "phone": "1554052685",
    "notes": "Quasi quisquam tenetur sint quas. Fugit quisquam pariatur rerum. Nulla sit mollitia. Quis dolores dolore eligendi similique magnam numquam sint ea aliquid. Eveniet possimus vitae.",
    "whatsapp_share_link": "https://api.whatsapp.com/send?text=%E2%80%8F%E2%80%8Ehttps%3A%2F%2Fwww.google.com%2Fmaps%2Fdir%2F%3Fapi%3D1%26destination%3D24.2222%2C46.5555",
    "map_location": {
      "lat": 24.2222,
      "lng": 46.5555,
      "address_name": "محرم بيك شارع المطافي عماره عشره"
    }
  }
}
```

#### 400 — حقل الاسم مطلوب. (ar)

```json
{
  "status": 400,
  "message": "حقل الاسم مطلوب.",
  "errors": {
    "name": "حقل الاسم مطلوب.",
    "map_location": "حقل map location مطلوب.",
    "map_location.lat": "حقل map location.lat مطلوب.",
    "map_location.lng": "حقل map location.lng مطلوب.",
    "map_location.address_name": "حقل map location.address name مطلوب."
  },
  "data": {}
}
```

#### 400 — حقل map location.lat مطلوب. (ar)

```json
{
  "status": 400,
  "message": "حقل map location.lat مطلوب.",
  "errors": {
    "map_location.lat": "حقل map location.lat مطلوب."
  },
  "data": {}
}
```

### Update

| | |
|---|---|
| **Method** | `PUT` |
| **Path** | `/profile/address-book/22` |
| **Full URL** | `https://demo.safaria.travel/api/v1/profile/address-book/22` |
| **Auth** | Bearer token required |
| **Folder** | addresses |

**Body (JSON):**

```json
{
  "name": "{{$randomFullName}}",
  "phone": "1554052685",
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
| `Accept-Language` | `ar` \| `en` (app locale) |

**Saved responses:**

| HTTP | Scenario | Language | Error fields |
|------|----------|----------|--------------|
| `200` | Updated | ar | — |
| `200` | Updated | ar | — |
| `400` | حقل الاسم مطلوب. | ar | `name`, `map_location`, `map_location.lat`, `map_location.lng`, `map_location.address_name` |
| `404` | Record not found | ar | — |

#### 200 — Updated (ar)

```json
{
  "status": 200,
  "message": "Updated",
  "errors": {},
  "data": {
    "id": 14,
    "city": null,
    "name": "Miss Elisa Reichert",
    "phone": "1090510796",
    "notes": "et nisi non",
    "whatsapp_share_link": "https://api.whatsapp.com/send?text=%E2%80%8F%E2%80%8Ehttps%3A%2F%2Fwww.google.com%2Fmaps%2Fdir%2F%3Fapi%3D1%26destination%3D31.04472075614%2C31.379182285063",
    "map_location": {
      "lat": 31.04472075613956,
      "lng": 31.379182285062797,
      "address_name": "2716 Willms Route"
    }
  }
}
```

#### 200 — Updated (ar)

```json
{
  "status": 200,
  "message": "Updated",
  "errors": {},
  "data": {
    "id": 22,
    "city": null,
    "name": "Emanuel Lowe",
    "phone": "1554052685",
    "notes": "Eaque odio odio dignissimos. Corporis sunt et doloremque nesciunt enim ipsam minima et non. Ut eos in. Ipsum corporis sed quam at aut vel voluptatem et soluta. Consequatur labore itaque cumque non ut qui magni mollitia. Odio autem a ut.",
    "whatsapp_share_link": "https://api.whatsapp.com/send?text=%E2%80%8F%E2%80%8Ehttps%3A%2F%2Fwww.google.com%2Fmaps%2Fdir%2F%3Fapi%3D1%26destination%3D31.04472075614%2C31.379182285063",
    "map_location": {
      "lat": 31.04472075613956,
      "lng": 31.379182285062797,
      "address_name": "6358 Ike Skyway"
    }
  }
}
```

#### 400 — حقل الاسم مطلوب. (ar)

```json
{
  "status": 400,
  "message": "حقل الاسم مطلوب.",
  "errors": {
    "name": "حقل الاسم مطلوب.",
    "map_location": "حقل map location مطلوب.",
    "map_location.lat": "حقل map location.lat مطلوب.",
    "map_location.lng": "حقل map location.lng مطلوب.",
    "map_location.address_name": "حقل map location.address name مطلوب."
  },
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

### Delete

| | |
|---|---|
| **Method** | `DELETE` |
| **Path** | `/profile/address-book/12` |
| **Full URL** | `https://demo.safaria.travel/api/v1/profile/address-book/12` |
| **Auth** | Bearer token required |
| **Folder** | addresses |

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |
| `Accept-Language` | `ar` \| `en` (app locale) |

**Saved responses:**

| HTTP | Scenario | Language | Error fields |
|------|----------|----------|--------------|
| `404` | Record not found | ar | — |
| `200` | Deleted | ar | — |

#### 404 — Record not found (ar)

```json
{
  "status": 404,
  "message": "This record can't be found",
  "errors": {},
  "data": {}
}
```

#### 200 — Deleted (ar)

```json
{
  "status": 200,
  "message": "Deleted",
  "errors": {},
  "data": {}
}
```

#### Notifications

### List

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/profile/notifications` |
| **Full URL** | `https://demo.safaria.travel/api/v1/profile/notifications` |
| **Auth** | Bearer token required |
| **Folder** | Notifications |

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |
| `Accept-Language` | `ar` \| `en` (app locale) |

**Saved responses:**

| HTTP | Scenario | Language | Error fields |
|------|----------|----------|--------------|
| `200` | Notification list | ar | — |

#### 200 — Notification list (ar)

```json
{
  "status": 200,
  "message": "Notification list",
  "errors": {},
  "data": [
    {
      "id": "f2ddd3f1-97f7-4797-a016-e5f31c29572c",
      "title": "تهانئ",
      "description": "تم توثيق حسابك بنجاح",
      "created_date": "2026-07-02 12:48:02",
      "formatted_date": "2026-07-02 12:48 pm",
      "data": {},
      "read_at": "2026-07-02T10:56:45.000000Z"
    },
    {
      "id": "44fe3341-a5f2-4681-b166-d558fe48087d",
      "title": "تهانئ",
      "description": "تم توثيق حسابك بنجاح",
      "created_date": "2026-07-02 12:46:05",
      "formatted_date": "2026-07-02 12:46 pm",
      "data": {},
      "read_at": "2026-07-02T10:56:45.000000Z"
    }
  ],
  "pagination": {
    "total": 2,
    "lastPage": 1,
    "perPage": 15,
    "currentPage": 1,
    "nextPageUrl": null,
    "previousPageUrl": null
  }
}
```

### Delete

| | |
|---|---|
| **Method** | `DELETE` |
| **Path** | `/profile/notifications` |
| **Full URL** | `https://demo.safaria.travel/api/v1/profile/notifications` |
| **Auth** | Bearer token required |
| **Folder** | Notifications |

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |
| `Accept-Language` | `ar` \| `en` (app locale) |

**Saved responses:**

| HTTP | Scenario | Language | Error fields |
|------|----------|----------|--------------|
| `200` | Notification has been deleted | ar | — |

#### 200 — Notification has been deleted (ar)

```json
{
  "status": 200,
  "message": "Notification has been deleted",
  "errors": {},
  "data": {}
}
```

#### Tickets > Replies

### List

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/profile/tickets/6/replies` |
| **Full URL** | `https://demo.safaria.travel/api/v1/profile/tickets/6/replies` |
| **Auth** | Bearer token required |
| **Folder** | Tickets > Replies |

**Body (form-data):** `file`, `message`

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |
| `Accept-Language` | `ar` \| `en` (app locale) |

### Create

| | |
|---|---|
| **Method** | `POST` |
| **Path** | `/profile/tickets/6/replies` |
| **Full URL** | `https://demo.safaria.travel/api/v1/profile/tickets/6/replies` |
| **Auth** | Bearer token required |
| **Folder** | Tickets > Replies |

**Body (form-data):** `message`, `attachments[]`

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |
| `Accept-Language` | `ar` \| `en` (app locale) |

#### Tickets

### Tickets list

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/profile/tickets` |
| **Full URL** | `https://demo.safaria.travel/api/v1/profile/tickets` |
| **Auth** | Bearer token required |
| **Folder** | Tickets |

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |
| `Accept-Language` | `ar` \| `en` (app locale) |

**Saved responses:**

| HTTP | Scenario | Language | Error fields |
|------|----------|----------|--------------|
| `200` | Tickets list | ar | — |

#### 200 — Tickets list (ar)

```json
{
  "status": 200,
  "message": "Tickets list",
  "errors": {},
  "data": [
    {
      "id": 2,
      "title": "missing button",
      "description": "missing button on anything",
      "status": "Opened",
      "section": "App Issues",
      "created_at": "2026-07-12 08:38 PM"
    }
  ],
  "pagination": {
    "total": 1,
    "lastPage": 1,
    "perPage": 15,
    "currentPage": 1,
    "nextPageUrl": null,
    "previousPageUrl": null
  }
}
```

### Show ticket

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/profile/tickets/10` |
| **Full URL** | `https://demo.safaria.travel/api/v1/profile/tickets/10` |
| **Auth** | Bearer token required |
| **Folder** | Tickets |

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |
| `Accept-Language` | `ar` \| `en` (app locale) |

### Create Ticket

| | |
|---|---|
| **Method** | `POST` |
| **Path** | `/profile/tickets` |
| **Full URL** | `https://demo.safaria.travel/api/v1/profile/tickets` |
| **Auth** | Bearer token required |
| **Folder** | Tickets |

**Body (form-data):** `title`, `description`, `section`

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |
| `Accept-Language` | `ar` \| `en` (app locale) |

#### Wallet

### List transactions

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/profile/wallet` |
| **Full URL** | `https://demo.safaria.travel/api/v1/profile/wallet` |
| **Auth** | Bearer token required |
| **Folder** | Wallet |

**Body (form-data):** `name`, `email`, `mobile`, `country_code`, `avatar`, `password`, `password_confirmation`

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |
| `Accept-Language` | `ar` \| `en` (app locale) |

**Saved responses:**

| HTTP | Scenario | Language | Error fields |
|------|----------|----------|--------------|
| `200` | Wallet balance | ar | — |

#### 200 — Wallet balance (ar)

```json
{
  "status": 200,
  "message": "Wallet",
  "errors": {},
  "data": [
    {
      "id": 79,
      "balance": "25.00",
      "transactions": [
        {
          "id": 86,
          "description": "تم إضافة 25 جنيه لمحفظتك ترحيبًا بك معنا. ",
          "type": "deposit",
          "amount": "25.00"
        }
      ]
    }
  ]
}
```

### Charge

| | |
|---|---|
| **Method** | `POST` |
| **Path** | `/profile/wallet/:amount/charge` |
| **Full URL** | `https://demo.safaria.travel/api/v1/profile/wallet/:amount/charge` |
| **Auth** | Bearer token required |
| **Folder** | Wallet |

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |
| `Accept-Language` | `ar` \| `en` (app locale) |

**Saved responses:**

| HTTP | Scenario | Language | Error fields |
|------|----------|----------|--------------|
| `200` | Payment link (×2) | ar | — |

#### 200 — Payment link (ar)

```json
{
  "status": 200,
  "message": "Payment link",
  "errors": {},
  "data": {
    "link": "https://demo.MyFatoorah.com/KWT/ia/…"
  }
}
```

#### Orders > Flights

### List

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/profile/flights/orders` |
| **Full URL** | `https://demo.safaria.travel/api/v1/profile/flights/orders` |
| **Auth** | Bearer token required |
| **Folder** | Orders > Flights |

**Body (form-data):** `file`, `message`

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |
| `Accept-Language` | `ar` \| `en` (app locale) |

### Show

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/profile/flights/orders/:id` |
| **Full URL** | `https://demo.safaria.travel/api/v1/profile/flights/orders/:id` |
| **Auth** | Bearer token required |
| **Folder** | Orders > Flights |

**Body (form-data):** `file`, `message`

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |
| `Accept-Language` | `ar` \| `en` (app locale) |

#### Orders > Buses

### List

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/profile/buses/orders` |
| **Full URL** | `https://demo.safaria.travel/api/v1/profile/buses/orders` |
| **Auth** | Bearer token required |
| **Folder** | Orders > Buses |

**Body (form-data):** `file`, `message`

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |
| `Accept-Language` | `ar` \| `en` (app locale) |

**Saved responses:**

| HTTP | Scenario | Language | Error fields |
|------|----------|----------|--------------|
| `200` | Bus orders list | ar | — |

#### 200 — Bus orders list (ar)

```json
{
  "status": 200,
  "message": "Bus orders",
  "errors": {},
  "data": [
    {
      "number": "000001475",
      "id": 1475,
      "trip_id": "145261",
      "gateway_order_id": "5077099",
      "parent_order_id": null,
      "company_data": {
        "name": "SuperJet",
        "avatar": "",
        "bus_image": "",
        "pin": ""
      },
      "status": "Pending",
      "status_code": "pending",
      "gateway_id": "SuperJet",
      "company_name": "SuperJet",
      "category": "Five stars",
      "can_be_cancel": true,
      "trip_type": "Buses",
      "is_confirmed": 0,
      "review": null,
      "can_review": false,
      "payment_data": {
        "status": "Pending",
        "status_code": "pending",
        "invoice_id": 6956732,
        "gateway": "Myfatoorah",
        "invoice_url": "https://demo.MyFatoorah.com/KWT/ia/…",
        "data": {
          "notes": ""
        }
      },
      "invoice_url": "https://portal.wdenytravel.com/orders/1475/invoice/…",
      "station_from": null,
      "station_to": null,
      "tickets": [
        {
          "id": 2076,
          "seat_number": "1",
          "price": "205.00"
        }
      ],
      "date": "2026-07-30",
      "date_time": "2026-07-30 08:45 AM",
      "payment_url": "https://portal.wdenytravel.com/api/v1/buses/orders/1475/…",
      "cancel_url": "https://portal.wdenytravel.com/api/v1/buses/orders/1475/cancel",
      "original_tickets_totals": "EGP 205.00",
      "discount": "EGP 0.00",
      "wallet_discount": "EGP 0.00",
      "tickets_totals_after_discount": "EGP 205.00",
      "payment_fees": "EGP 14.35",
      "total": "EGP 219.35",
      "currency": "EGP"
    },
    {
      "number": "000001472",
      "id": 1472,
      "trip_id": "145658",
      "gateway_order_id": "5062716",
      "parent_order_id": null,
      "company_data": {
        "name": "SuperJet",
        "avatar": "",
        "bus_image": "",
        "pin": ""
      },
      "status": "Pending",
      "status_code": "pending",
      "gateway_id": "SuperJet",
      "company_name": "SuperJet",
      "category": "VIP",
      "can_be_cancel": true,
      "trip_type": "Buses",
      "is_confirmed": 0,
      "review": null,
      "can_review": false,
      "payment_data": {
        "status": "Pending",
        "status_code": "pending",
        "invoice_id": 6952164,
        "gateway": "Myfatoorah",
        "invoice_url": "https://demo.MyFatoorah.com/KWT/ia/…",
        "data": {
          "notes": ""
        }
      },
      "invoice_url": "https://portal.wdenytravel.com/orders/1472/invoice/…",
      "station_from": null,
      "station_to": null,
      "tickets": [
        {
          "id": 2072,
          "seat_number": "4",
          "price": "225.00"
        }
      ],
      "date": "2026-07-30",
      "date_time": "2026-07-30 04:30 AM",
      "payment_url": "https://portal.wdenytravel.com/api/v1/buses/orders/1472/…",
      "cancel_url": "https://portal.wdenytravel.com/api/v1/buses/orders/1472/cancel",
      "original_tickets_totals": "EGP 225.00",
      "discount": "EGP 0.00",
      "wallet_discount": "EGP 0.00",
      "tickets_totals_after_discount": "EGP 225.00",
      "payment_fees": "EGP 15.75",
      "total": "EGP 240.75",
      "currency": "EGP"
    },
    {
      "number": "000001470",
      "id": 1470,
      "trip_id": "145658",
      "gateway_order_id": "5062449",
      "parent_order_id": null,
      "company_data": {
        "name": "SuperJet",
        "avatar": "",
        "bus_image": "",
        "pin": ""
      },
      "status": "Pending",
      "status_code": "pending",
      "gateway_id": "SuperJet",
      "company_name": "SuperJet",
      "category": "VIP",
      "can_be_cancel": true,
      "trip_type": "Buses",
      "is_confirmed": 0,
      "review": null,
      "can_review": false,
      "payment_data": {
        "status": "Pending",
        "status_code": "pending",
        "invoice_id": 6952142,
        "gateway": "Myfatoorah",
        "invoice_url": "https://demo.MyFatoorah.com/KWT/ia/…",
        "data": {
          "notes": ""
        }
      },
      "invoice_url": "https://portal.wdenytravel.com/orders/1470/invoice/…",
      "station_from": null,
      "station_to": null,
      "tickets": [
        {
          "id": 2070,
          "seat_number": "10",
          "price": "225.00"
        }
      ],
      "date": "2026-07-30",
      "date_time": "2026-07-30 04:30 AM",
      "payment_url": "https://portal.wdenytravel.com/api/v1/buses/orders/1470/…",
      "cancel_url": "https://portal.wdenytravel.com/api/v1/buses/orders/1470/cancel",
      "original_tickets_totals": "EGP 225.00",
      "discount": "EGP 0.00",
      "wallet_discount": "EGP 0.00",
      "tickets_totals_after_discount": "EGP 225.00",
      "payment_fees": "EGP 15.75",
      "total": "EGP 240.75",
      "currency": "EGP"
    },
    "…10 more items"
  ],
  "pagination": {
    "total": 13,
    "lastPage": 1,
    "perPage": 15,
    "currentPage": 1,
    "nextPageUrl": null,
    "previousPageUrl": null
  }
}
```

### Show

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/profile/buses/orders/:id` |
| **Full URL** | `https://demo.safaria.travel/api/v1/profile/buses/orders/:id` |
| **Auth** | Bearer token required |
| **Folder** | Orders > Buses |

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |
| `Accept-Language` | `ar` \| `en` (app locale) |

**Saved responses:**

| HTTP | Scenario | Language | Error fields |
|------|----------|----------|--------------|
| `200` | Bus order details | ar | — |
| `404` | Bus order not found | ar | — |

#### 200 — Bus order details (ar)

```json
{
  "status": 200,
  "message": "Bus order",
  "errors": {},
  "data": {
    "number": "000001475",
    "id": 1475,
    "trip_id": "145261",
    "gateway_order_id": "5077099",
    "parent_order_id": null,
    "company_data": {
      "name": "SuperJet",
      "avatar": "",
      "bus_image": "",
      "pin": ""
    },
    "status": "Pending",
    "status_code": "pending",
    "gateway_id": "SuperJet",
    "company_name": "SuperJet",
    "category": "Five stars",
    "can_be_cancel": true,
    "trip_type": "Buses",
    "is_confirmed": 0,
    "review": null,
    "can_review": false,
    "payment_data": {
      "status": "Pending",
      "status_code": "pending",
      "invoice_id": 6956732,
      "gateway": "Myfatoorah",
      "invoice_url": "https://demo.MyFatoorah.com/KWT/ia/…",
      "data": {
        "notes": ""
      }
    },
    "invoice_url": "https://portal.wdenytravel.com/orders/1475/invoice/…",
    "station_from": null,
    "station_to": null,
    "tickets": [
      {
        "id": 2076,
        "seat_number": "1",
        "price": "205.00"
      }
    ],
    "date": "2026-07-30",
    "date_time": "2026-07-30 08:45 AM",
    "payment_url": "https://portal.wdenytravel.com/api/v1/buses/orders/1475/…",
    "cancel_url": "https://portal.wdenytravel.com/api/v1/buses/orders/1475/cancel",
    "original_tickets_totals": "EGP 205.00",
    "discount": "EGP 0.00",
    "wallet_discount": "EGP 0.00",
    "tickets_totals_after_discount": "EGP 205.00",
    "payment_fees": "EGP 14.35",
    "total": "EGP 219.35",
    "currency": "EGP"
  }
}
```

#### 404 — Bus order not found (ar)

```json
{
  "status": 404,
  "message": "Bus order not found",
  "errors": {},
  "data": {}
}
```

#### Orders > Private

### List

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/profile/private/orders` |
| **Full URL** | `https://demo.safaria.travel/api/v1/profile/private/orders` |
| **Auth** | Bearer token required |
| **Folder** | Orders > Private |

**Body (form-data):** `file`, `message`

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |
| `Accept-Language` | `ar` \| `en` (app locale) |

### Show

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/profile/private/orders/:id` |
| **Full URL** | `https://demo.safaria.travel/api/v1/profile/private/orders/:id` |
| **Auth** | Bearer token required |
| **Folder** | Orders > Private |

**Body (form-data):** `file`, `message`

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |
| `Accept-Language` | `ar` \| `en` (app locale) |

### Show profile

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/profile` |
| **Full URL** | `https://demo.safaria.travel/api/v1/profile` |
| **Auth** | Bearer token required |

**Body (form-data):** `name`, `email`, `mobile`, `country_code`, `avatar`

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |
| `Accept-Language` | `ar` \| `en` (app locale) |

### Update profile

| | |
|---|---|
| **Method** | `POST` |
| **Path** | `/profile` |
| **Full URL** | `https://demo.safaria.travel/api/v1/profile` |
| **Auth** | Bearer token required |

**Body (form-data):** `name`, `email`, `mobile`, `country_code`, `avatar`

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |
| `Accept-Language` | `ar` \| `en` (app locale) |

### Update Token

| | |
|---|---|
| **Method** | `PUT` |
| **Path** | `/profile/firebase/token` |
| **Full URL** | `https://demo.safaria.travel/api/v1/profile/firebase/token` |
| **Auth** | Bearer token required |

**Body (form-data):** 

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |
| `Accept-Language` | `ar` \| `en` (app locale) |

### Verify Alt phone

| | |
|---|---|
| **Method** | `POST` |
| **Path** | `/profile/verify-alt-phone` |
| **Full URL** | `https://demo.safaria.travel/api/v1/profile/verify-alt-phone` |
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
| `Accept-Language` | `ar` \| `en` (app locale) |

### Update password

| | |
|---|---|
| **Method** | `POST` |
| **Path** | `/profile/update-password` |
| **Full URL** | `https://demo.safaria.travel/api/v1/profile/update-password` |
| **Auth** | Bearer token required |

**Body (form-data):** `current_password`, `new_password`, `new_password_confirmation`

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |
| `Accept-Language` | `ar` \| `en` (app locale) |

### Delete account

| | |
|---|---|
| **Method** | `DELETE` |
| **Path** | `/profile` |
| **Full URL** | `https://demo.safaria.travel/api/v1/profile` |
| **Auth** | Bearer token required |

**Body (form-data):** 

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |
| `Accept-Language` | `ar` \| `en` (app locale) |
| `firebase_token` | AhMeDs |

**Saved responses:**

| HTTP | Scenario | Language | Error fields |
|------|----------|----------|--------------|
| `200` | Account deleted | ar | — |
| `401` | Unauthenticated | ar | — |

#### 200 — Account deleted (ar)

```json
{
  "status": 200,
  "message": "Account deleted",
  "errors": {},
  "data": {}
}
```

#### 401 — Unauthenticated (ar)

```json
{
  "status": 401,
  "message": "Unauthenticated",
  "errors": {},
  "data": {}
}
```

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
| **Full URL** | `https://demo.safaria.travel/api/v1/posts?category_id=1` |
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
| `Accept-Language` | `ar` \| `en` (app locale) |

### Show

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/posts/:slug` |
| **Full URL** | `https://demo.safaria.travel/api/v1/posts/:slug` |
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
| `Accept-Language` | `ar` \| `en` (app locale) |

### Categories

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/posts/categories` |
| **Full URL** | `https://demo.safaria.travel/api/v1/posts/categories` |
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
| `Accept-Language` | `ar` \| `en` (app locale) |

### Banners list

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/banners` |
| **Full URL** | `https://demo.safaria.travel/api/v1/banners` |
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
| `Accept-Language` | `ar` \| `en` (app locale) |

### Faq

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/faq` |
| **Full URL** | `https://demo.safaria.travel/api/v1/faq` |
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
| `Accept-Language` | `ar` \| `en` (app locale) |

### Partners list

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/partners` |
| **Full URL** | `https://demo.safaria.travel/api/v1/partners` |
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
| `Accept-Language` | `ar` \| `en` (app locale) |

### Contact us

| | |
|---|---|
| **Method** | `POST` |
| **Path** | `/contact` |
| **Full URL** | `https://demo.safaria.travel/api/v1/contact` |
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
| `Accept-Language` | `ar` \| `en` (app locale) |

### Pages

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/pages` |
| **Full URL** | `https://demo.safaria.travel/api/v1/pages` |
| **Auth** | Bearer token required |

**Body (JSON):**

```json
]
```

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |
| `Accept-Language` | `ar` \| `en` (app locale) |

### Show Page

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/pages/sy-s-lkhsosy` |
| **Full URL** | `https://demo.safaria.travel/api/v1/pages/sy-s-lkhsosy` |
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
| `Accept-Language` | `ar` \| `en` (app locale) |

### Countries List

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/countries` |
| **Full URL** | `https://demo.safaria.travel/api/v1/countries` |
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
| `Accept-Language` | `ar` \| `en` (app locale) |

### Settings

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/settings` |
| **Full URL** | `https://demo.safaria.travel/api/v1/settings` |
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
| `Accept-Language` | `ar` \| `en` (app locale) |

### New Request

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `*(not configured)*` |
| **Full URL** | `*(not configured)*` |
| **Auth** | Bearer token required |

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |
| `Accept-Language` | `ar` \| `en` (app locale) |

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
| **Full URL** | `https://demo.safaria.travel/api/v1/flights/iata?search=CAI` |
| **Auth** | Bearer token required |

**Query parameters:**

| Parameter | Example |
|-----------|---------|
| `search` | CAI |

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |
| `Accept-Language` | `ar` \| `en` (app locale) |

### Airports

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/flights/airports/search` |
| **Full URL** | `https://demo.safaria.travel/api/v1/flights/airports/search?term=دبي` |
| **Auth** | Bearer token required |

**Query parameters:**

| Parameter | Example |
|-----------|---------|
| `term` | دبي |

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |
| `Accept-Language` | `ar` \| `en` (app locale) |

### Search

| | |
|---|---|
| **Method** | `POST` |
| **Path** | `/flights/search` |
| **Full URL** | `https://demo.safaria.travel/api/v1/flights/search` |
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
| `Accept-Language` | `ar` \| `en` (app locale) |

### Confirm Order

| | |
|---|---|
| **Method** | `POST` |
| **Path** | `/flights/:offer_id/confirm` |
| **Full URL** | `https://demo.safaria.travel/api/v1/flights/:offer_id/confirm` |
| **Auth** | Bearer token required |

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |
| `Accept-Language` | `ar` \| `en` (app locale) |

### Bundels

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/flights/:offer_id/bundles` |
| **Full URL** | `https://demo.safaria.travel/api/v1/flights/:offer_id/bundles?=` |
| **Auth** | Bearer token required |

**Query parameters:**

| Parameter | Example |
|-----------|---------|
| `` |  |

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |
| `Accept-Language` | `ar` \| `en` (app locale) |

### Add Passenger

| | |
|---|---|
| **Method** | `POST` |
| **Path** | `/flights/:offer_id/passengers` |
| **Full URL** | `https://demo.safaria.travel/api/v1/flights/:offer_id/passengers` |
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
| `Accept-Language` | `ar` \| `en` (app locale) |

### Hold Trip

| | |
|---|---|
| **Method** | `POST` |
| **Path** | `/flights/:offer_id/hold` |
| **Full URL** | `https://demo.safaria.travel/api/v1/flights/:offer_id/hold` |
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
| `Accept-Language` | `ar` \| `en` (app locale) |

### Pending Trip

| | |
|---|---|
| **Method** | `POST` |
| **Path** | `/flights/:offer_id` |
| **Full URL** | `https://demo.safaria.travel/api/v1/flights/:offer_id` |
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
| `Accept-Language` | `ar` \| `en` (app locale) |
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
| **Full URL** | `https://demo.safaria.travel/api/v1/private/search?from_latitude=30.0314696&from_longitude=31.2612288&to_latitude=31.182972882989525&to_longitude=29.894801258559188&rounded=false` |
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
| `Accept-Language` | `ar` \| `en` (app locale) |

### Show Trip Details

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/flights/airports/search` |
| **Full URL** | `https://demo.safaria.travel/api/v1/flights/airports/search?term=دبي` |
| **Auth** | Bearer token required |

**Query parameters:**

| Parameter | Example |
|-----------|---------|
| `term` | دبي |

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |
| `Accept-Language` | `ar` \| `en` (app locale) |

### Orders

| | |
|---|---|
| **Method** | `POST` |
| **Path** | `/private/orders` |
| **Full URL** | `https://demo.safaria.travel/api/v1/private/orders` |
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
| `Accept-Language` | `ar` \| `en` (app locale) |
| `Authorization` | Bearer {{token}} |

## Buses

| # | Method | Path | Name |
|---|--------|------|------|
| 1 | `GET` | `/buses/locations` | Locations |
| 2 | `GET` | `/buses/stations` | Stations |
| 3 | `GET` | `/buses/carriers` | Carriers |
| 4 | `GET` | `/buses/trips` | Search trips |
| 5 | `GET` | `/buses/trips/236510` | Search details |
| 6 | `GET` | `/buses/trips/236510/seats` | Seats |
| 7 | `POST` | `/buses/trips/236437/create-ticket` | Create Ticket |
| 8 | `GET` | `—` | cancel |

### Response envelope

All Buses endpoints return JSON with this shape (HTTP status may differ from the inner `status` field):

```json
{
  "status": 200,
  "message": "…",
  "errors": {},
  "data": {}
}
```

- List endpoints (`locations`, `stations`, `carriers`, `trips`) return `data` as an **array**.
- `search trips` also includes a top-level `pagination` object.
- `seats` and `create-ticket` return `data` as an **object** (seat map / order).
- `errors` values are **strings** in live responses; the mobile app normalizes strings and arrays.

### Locations

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/buses/locations` |
| **Full URL** | `https://demo.safaria.travel/api/v1/buses/locations` |
| **Auth** | Bearer token required |

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |
| `Accept-Language` | `ar` \| `en` (app locale) |

**Saved responses:**

| HTTP | Scenario | Language | Error fields |
|------|----------|----------|--------------|
| `200` | Locations list (×2) | ar | — |
| `200` | Empty results | en | — |
| `200` | Locations list | en | — |

#### 200 — Locations list (ar)

```json
{
  "status": 200,
  "message": "Locations list",
  "errors": {},
  "data": [
    {
      "id": 1,
      "name": "القاهره",
      "name_ar": "القاهره",
      "name_en": "Cairo"
    },
    {
      "id": 2,
      "name": "الاسكندريه",
      "name_ar": "الاسكندريه",
      "name_en": "Alexandria"
    },
    {
      "id": 4,
      "name": "الغردقه",
      "name_ar": "الغردقه",
      "name_en": "Hurghada"
    },
    "…48 more items"
  ]
}
```

#### 200 — Empty results (en)

```json
{
  "status": 200,
  "message": "Locations list",
  "errors": {},
  "data": []
}
```

#### 200 — Locations list (en)

```json
{
  "status": 200,
  "message": "Locations list",
  "errors": {},
  "data": [
    {
      "id": 258,
      "name": "السادس من اكتوبر",
      "name_ar": "السادس من اكتوبر",
      "name_en": "السادس من اكتوبر"
    }
  ]
}
```

### Stations

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/buses/stations` |
| **Full URL** | `https://demo.safaria.travel/api/v1/buses/stations` |
| **Auth** | Bearer token required |

**Query parameters:**

| Parameter | Example |
|-----------|---------|
| `term` | سوها |
| `pagination` | false |

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |
| `Accept-Language` | `ar` \| `en` (app locale) |

**Saved responses:**

| HTTP | Scenario | Language | Error fields |
|------|----------|----------|--------------|
| `200` | stations list | ar | — |

#### 200 — stations list (ar)

```json
{
  "status": 200,
  "message": "stations list",
  "errors": {},
  "data": [
    {
      "id": 206,
      "station_id": "309",
      "name": "رمسيس",
      "name_ar": "رمسيس",
      "name_en": "رمسيس",
      "carrier_id": 7,
      "carrier_name": "مستر باص للنقل البري",
      "city_gateway_id": 193,
      "map_location": {
        "lat": 30.0607175,
        "lng": 31.245912
      },
      "city": {
        "id": 1,
        "name": "القاهره",
        "name_ar": "القاهره",
        "name_en": "Cairo"
      }
    },
    {
      "id": 207,
      "station_id": "310",
      "name": "قنا 1",
      "name_ar": "قنا 1",
      "name_en": "قنا 1",
      "carrier_id": 7,
      "carrier_name": "مستر باص للنقل البري",
      "city_gateway_id": 61,
      "map_location": {
        "lat": 26.1638256,
        "lng": 32.7264104
      },
      "city": {
        "id": 64,
        "name": "قنا",
        "name_ar": "قنا",
        "name_en": "Qena"
      }
    },
    {
      "id": 208,
      "station_id": "311",
      "name": "دشنا",
      "name_ar": "دشنا",
      "name_en": "دشنا",
      "carrier_id": 7,
      "carrier_name": "مستر باص للنقل البري",
      "city_gateway_id": 125,
      "map_location": {
        "lat": 26.1265405,
        "lng": 32.4716482
      },
      "city": {
        "id": 98,
        "name": "دشنا",
        "name_ar": "دشنا",
        "name_en": "deshna"
      }
    },
    "…12 more items"
  ],
  "pagination": {
    "total": 137,
    "lastPage": 10,
    "perPage": 15,
    "currentPage": 1,
    "nextPageUrl": "https://portal.wdenytravel.com/api/v1/buses/stations?page=2",
    "previousPageUrl": null
  }
}
```

### Carriers

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/buses/carriers` |
| **Full URL** | `https://demo.safaria.travel/api/v1/buses/carriers` |
| **Auth** | Bearer token required |

**Query parameters:**

| Parameter | Example |
|-----------|---------|
| `term` | سوها |

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |
| `Accept-Language` | `ar` \| `en` (app locale) |

**Saved responses:**

| HTTP | Scenario | Language | Error fields |
|------|----------|----------|--------------|
| `200` | Carriers list | ar | — |

#### 200 — Carriers list (ar)

```json
{
  "status": 200,
  "message": "carriers list",
  "errors": {},
  "data": [
    {
      "id": 1,
      "name": "بلو باص",
      "name_ar": "بلو باص",
      "name_en": "Blue Bus",
      "logo": "https://portal.wdenytravel.com/logo.svg"
    },
    {
      "id": 2,
      "name": "اون تايم",
      "name_ar": "اون تايم",
      "name_en": "OnTime",
      "logo": "https://portal.wdenytravel.com/logo.svg"
    },
    {
      "id": 6,
      "name": "هاى جيت للنقل البرى والبحرى",
      "name_ar": "هاى جيت للنقل البرى والبحرى",
      "name_en": "هاى جيت للنقل البرى والبحرى",
      "logo": "https://portal.wdenytravel.com/logo.svg"
    },
    "…27 more items"
  ]
}
```

### Search trips

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/buses/trips` |
| **Full URL** | `https://demo.safaria.travel/api/v1/buses/trips?city_from=1&city_to=2&date=2026-07-29&page=1&currency=EGP` |
| **Auth** | Bearer token required |

**Query parameters:**

| Parameter | Example |
|-----------|---------|
| `city_from` | 1 |
| `city_to` | 2 |
| `date` | 2026-07-29 |
| `page` | 1 |
| `page` | 2 |
| `currency` | EGP |

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |
| `Accept-Language` | `ar` \| `en` (app locale) |

**Saved responses:**

| HTTP | Scenario | Language | Error fields |
|------|----------|----------|--------------|
| `200` | Trips list | ar | — |
| `200` | Locations list | ar | — |
| `200` | Trips list | en | — |
| `200` | Trips list | en | — |

#### 200 — Trips list (ar)

```json
{
  "status": 200,
  "message": "Trips list",
  "errors": {},
  "data": [
    {
      "id": 290545,
      "gateway_id": "Tazcara",
      "company": "النورس للنقل البري",
      "company_data": {
        "name": "النورس للنقل البري",
        "avatar": "https://telefreik-app.test/storage/companies/40.png",
        "bus_image": "https://telefreik-app.test/assets/images/buses/default.jpeg",
        "pin": "https://telefreik-app.test/assets/images/pins/nowras.png"
      },
      "category": "VIP",
      "date": "2025-02-10",
      "time": "07:00 am",
      "date_time": "2025-02-10 07:00",
      "bus": {
        "id": 290545,
        "code": "النورس للنقل البري-290545",
        "category": "VIP",
        "salon": "vip",
        "type": "bus"
      },
      "cities_from": [
        {
          "id": 1,
          "name": "القاهره",
          "latitude": "",
          "longitude": "",
          "price": 0
        }
      ],
      "cities_to": [
        {
          "id": 2,
          "name": "الاسكندريه",
          "latitude": "",
          "longitude": "",
          "price": 0
        }
      ],
      "stations_from": [
        {
          "id": 985052,
          "city_id": 1,
          "city_name": "القاهره",
          "arrival_at": "2025-02-10 07:00:00",
          "name": "القللي",
          "latitude": "30.060136",
          "longitude": "31.243630",
          "price": 0,
          "original_price": 0,
          "final_price": 0,
          "categories": []
        }
      ],
      "stations_to": [
        {
          "id": 985053,
          "city_id": 2,
          "city_name": "الاسكندريه",
          "arrival_at": "2025-02-10 10:00:00",
          "name": "محرم بك",
          "latitude": "",
          "longitude": "",
          "price": 148.5,
          "original_price": 150,
          "final_price": 148.5
        }
      ],
      "pricing": [],
      "price_start_with": 148.5,
      "prices_start_with": {
        "original_price": 150,
        "final_price": 148.5,
        "offer": "1%"
      },
      "available_seats": 0
    },
    {
      "id": 291382,
      "gateway_id": "Tazcara",
      "company": "هاى جيت للنقل البرى والبحرى",
      "company_data": {
        "name": "هاى جيت للنقل البرى والبحرى",
        "avatar": "https://telefreik-app.test/storage/companies/29.png",
        "bus_image": "https://telefreik-app.test/assets/images/buses/default.jpeg",
        "pin": "https://telefreik-app.test/assets/images/pins/highjet.png"
      },
      "category": "Economy",
      "date": "2025-02-10",
      "time": "05:00 pm",
      "date_time": "2025-02-10 17:00",
      "bus": {
        "id": 291382,
        "code": "هاى جيت للنقل البرى والبحرى-291382",
        "category": "Economy",
        "salon": "economy",
        "type": "bus"
      },
      "cities_from": [
        {
          "id": 1,
          "name": "القاهره",
          "latitude": "",
          "longitude": "",
          "price": 0
        }
      ],
      "cities_to": [
        {
          "id": 2,
          "name": "الاسكندريه",
          "latitude": "",
          "longitude": "",
          "price": 0
        }
      ],
      "stations_from": [
        {
          "id": 989250,
          "city_id": 1,
          "city_name": "القاهره",
          "arrival_at": "2025-02-10 17:00:00",
          "name": "القللى",
          "latitude": "",
          "longitude": "",
          "price": 0,
          "original_price": 0,
          "final_price": 0,
          "categories": []
        },
        {
          "id": 989251,
          "city_id": 1,
          "city_name": "القاهره",
          "arrival_at": "2025-02-10 17:15:00",
          "name": "احمد حلمى",
          "latitude": "",
          "longitude": "",
          "price": 0,
          "original_price": 0,
          "final_price": 0,
          "categories": []
        }
      ],
      "stations_to": [
        {
          "id": 989252,
          "city_id": 2,
          "city_name": "الاسكندريه",
          "arrival_at": "2025-02-10 20:30:00",
          "name": "محرم بيك",
          "latitude": "",
          "longitude": "",
          "price": 118.8,
          "original_price": 120,
          "final_price": 118.8
        }
      ],
      "pricing": [],
      "price_start_with": 118.8,
      "prices_start_with": {
        "original_price": 120,
        "final_price": 118.8,
        "offer": "1%"
      },
      "available_seats": 0
    }
  ],
  "pagination": {
    "total": 2,
    "lastPage": 1,
    "perPage": 10,
    "currentPage": 1,
    "nextPageUrl": null,
    "previousPageUrl": null
  }
}
```

#### 200 — Locations list (ar)

```json
{
  "status": 200,
  "message": "Locations list",
  "errors": {},
  "data": [
    {
      "id": 1,
      "name": "القاهره",
      "name_ar": "القاهره",
      "name_en": "Cairo"
    },
    {
      "id": 2,
      "name": "الاسكندريه",
      "name_ar": "الاسكندريه",
      "name_en": "Alexandria"
    },
    {
      "id": 4,
      "name": "الغردقه",
      "name_ar": "الغردقه",
      "name_en": "Hurghada"
    },
    "…48 more items"
  ]
}
```

#### 200 — Trips list (en)

```json
{
  "status": 200,
  "message": "Trips list",
  "errors": {},
  "data": [
    {
      "id": 236510,
      "gateway_id": "BlueBus",
      "currency": "SAR",
      "company": "Blue Bus",
      "company_data": {
        "id": 1,
        "name": "Blue Bus",
        "avatar": "",
        "bus_image": "",
        "pin": ""
      },
      "category": "first8",
      "date": "2026-07-10",
      "time": "12:01 am",
      "date_time": "2026-07-10 00:01",
      "bus": {
        "id": 236510,
        "code": "BlueBus-236510",
        "category": "first8",
        "salon": "first8",
        "type": "bus",
        "seats_count": 0
      },
      "cities_from": [
        {
          "id": 1,
          "name": "Cairo",
          "latitude": "1",
          "longitude": "1",
          "price": 0
        }
      ],
      "cities_to": [
        {
          "id": 2,
          "name": "Alexandria",
          "latitude": "1",
          "longitude": "1",
          "price": 0
        }
      ],
      "stations_from": [
        {
          "id": "50",
          "name": "Sekka Club",
          "city_id": 1,
          "city_name": "Cairo",
          "arrival_at": "2026-07-10 05:45:00",
          "latitude": "30.057569550064",
          "longitude": "31.304265372823",
          "currency": "SAR",
          "price": 0,
          "original_price": 0,
          "final_price": 0,
          "categories": []
        },
        {
          "id": "46",
          "name": "Ramsis",
          "city_id": 1,
          "city_name": "Cairo",
          "arrival_at": "2026-07-10 06:15:00",
          "latitude": "30.063437",
          "longitude": "31.252121",
          "currency": "SAR",
          "price": 0,
          "original_price": 0,
          "final_price": 0,
          "categories": []
        },
        {
          "id": "23",
          "name": "6 October",
          "city_id": 1,
          "city_name": "Cairo",
          "arrival_at": "2026-07-10 07:15:00",
          "latitude": "29.968428",
          "longitude": "30.938219",
          "currency": "SAR",
          "price": 0,
          "original_price": 0,
          "final_price": 0,
          "categories": []
        }
      ],
      "stations_to": [
        {
          "id": "22",
          "name": "Moharam Bek",
          "city_id": 2,
          "city_name": "Alexandria",
          "arrival_at": "2026-07-10 10:00:00",
          "latitude": "31.178158",
          "longitude": "29.915599",
          "currency": "SAR",
          "price": 26.2,
          "original_price": 26.2,
          "final_price": 26.2,
          "categories": []
        }
      ],
      "pricing": [],
      "price_start_with": 26.2,
      "prices_start_with": {
        "original_price": 26.2,
        "final_price": 26.2,
        "offer_price": "0"
      },
      "available_seats": 0,
      "original_price": 26.2,
      "foreigner_price": 26.2
    },
    {
      "id": 236528,
      "gateway_id": "Distribusion",
      "currency": "SAR",
      "company": "GO Bus",
      "company_data": {
        "id": 47,
        "name": "GO Bus",
        "avatar": "",
        "bus_image": "",
        "pin": ""
      },
      "category": "FARE-1",
      "date": "2026-07-10",
      "time": "12:05 am",
      "date_time": "2026-07-10 00:05",
      "bus": {
        "id": 236528,
        "code": "Distribusion-236528",
        "category": "FARE-1",
        "salon": "FARE-1",
        "type": "bus",
        "seats_count": 0
      },
      "cities_from": [
        {
          "id": 1,
          "name": "Cairo",
          "latitude": "1",
          "longitude": "1",
          "price": 0
        }
      ],
      "cities_to": [
        {
          "id": 2,
          "name": "Alexandria",
          "latitude": "1",
          "longitude": "1",
          "price": 0
        }
      ],
      "stations_from": [
        {
          "id": "EGCAIBCN",
          "name": " Cairo NasrCity Station",
          "city_id": 1,
          "city_name": "Cairo",
          "arrival_at": "2026-07-10 20:35:00",
          "latitude": "30.0468889",
          "longitude": "31.316978",
          "currency": "SAR",
          "price": 0,
          "original_price": 0,
          "final_price": 0,
          "categories": []
        }
      ],
      "stations_to": [
        {
          "id": "EGALEALG",
          "name": "Moharam Bek",
          "city_id": 2,
          "city_name": "Alexandria",
          "arrival_at": "2026-07-11 00:05:00",
          "latitude": "31.178104",
          "longitude": "29.914984",
          "currency": "SAR",
          "price": 17.05,
          "original_price": 17.05,
          "final_price": 17.05,
          "categories": []
        }
      ],
      "pricing": [],
      "price_start_with": 17.05,
      "prices_start_with": {
        "original_price": 17.05,
        "final_price": 17.05,
        "offer_price": 0
      },
      "available_seats": 0,
      "original_price": 17.05,
      "foreigner_price": 17.05
    },
    {
      "id": 236529,
      "gateway_id": "Distribusion",
      "currency": "SAR",
      "company": "GO Bus",
      "company_data": {
        "id": 47,
        "name": "GO Bus",
        "avatar": "",
        "bus_image": "",
        "pin": ""
      },
      "category": "FARE-1",
      "date": "2026-07-10",
      "time": "12:50 am",
      "date_time": "2026-07-10 00:50",
      "bus": {
        "id": 236529,
        "code": "Distribusion-236529",
        "category": "FARE-1",
        "salon": "FARE-1",
        "type": "bus",
        "seats_count": 0
      },
      "cities_from": [
        {
          "id": 1,
          "name": "Cairo",
          "latitude": "1",
          "longitude": "1",
          "price": 0
        }
      ],
      "cities_to": [
        {
          "id": 2,
          "name": "Alexandria",
          "latitude": "1",
          "longitude": "1",
          "price": 0
        }
      ],
      "stations_from": [
        {
          "id": "EGCAICAS",
          "name": "Abd El Monim Riad",
          "city_id": 1,
          "city_name": "Cairo",
          "arrival_at": "2026-07-10 21:20:00",
          "latitude": "30.05023",
          "longitude": "31.23328",
          "currency": "SAR",
          "price": 0,
          "original_price": 0,
          "final_price": 0,
          "categories": []
        }
      ],
      "stations_to": [
        {
          "id": "EGALEALG",
          "name": "Moharam Bek",
          "city_id": 2,
          "city_name": "Alexandria",
          "arrival_at": "2026-07-11 00:50:00",
          "latitude": "31.178104",
          "longitude": "29.914984",
          "currency": "SAR",
          "price": 17.05,
          "original_price": 17.05,
          "final_price": 17.05,
          "categories": []
        }
      ],
      "pricing": [],
      "price_start_with": 17.05,
      "prices_start_with": {
        "original_price": 17.05,
        "final_price": 17.05,
        "offer_price": 0
      },
      "available_seats": 0,
      "original_price": 17.05,
      "foreigner_price": 17.05
    },
    "…12 more items"
  ],
  "pagination": {
    "total": 36,
    "lastPage": 3,
    "perPage": 15,
    "currentPage": 1,
    "nextPageUrl": "https://portal.wdenytravel.com/api/v1/buses/trips?page=2",
    "previousPageUrl": null
  }
}
```

#### 200 — Trips list (en)

```json
{
  "status": 200,
  "message": "Trips list",
  "errors": {},
  "data": [
    {
      "id": 236510,
      "gateway_id": "BlueBus",
      "currency": "EGP",
      "company": "Blue Bus",
      "company_data": {
        "id": 1,
        "name": "Blue Bus",
        "avatar": "",
        "bus_image": "",
        "pin": ""
      },
      "category": "first8",
      "date": "2026-07-10",
      "time": "12:01 am",
      "date_time": "2026-07-10 00:01",
      "bus": {
        "id": 236510,
        "code": "BlueBus-236510",
        "category": "first8",
        "salon": "first8",
        "type": "bus",
        "seats_count": 0
      },
      "cities_from": [
        {
          "id": 1,
          "name": "Cairo",
          "latitude": "1",
          "longitude": "1",
          "price": 0
        }
      ],
      "cities_to": [
        {
          "id": 2,
          "name": "Alexandria",
          "latitude": "1",
          "longitude": "1",
          "price": 0
        }
      ],
      "stations_from": [
        {
          "id": "50",
          "name": "Sekka Club",
          "city_id": 1,
          "city_name": "Cairo",
          "arrival_at": "2026-07-10 05:45:00",
          "latitude": "30.057569550064",
          "longitude": "31.304265372823",
          "currency": "EGP",
          "price": 0,
          "original_price": 0,
          "final_price": 0,
          "categories": []
        },
        {
          "id": "46",
          "name": "Ramsis",
          "city_id": 1,
          "city_name": "Cairo",
          "arrival_at": "2026-07-10 06:15:00",
          "latitude": "30.063437",
          "longitude": "31.252121",
          "currency": "EGP",
          "price": 0,
          "original_price": 0,
          "final_price": 0,
          "categories": []
        },
        {
          "id": "23",
          "name": "6 October",
          "city_id": 1,
          "city_name": "Cairo",
          "arrival_at": "2026-07-10 07:15:00",
          "latitude": "29.968428",
          "longitude": "30.938219",
          "currency": "EGP",
          "price": 0,
          "original_price": 0,
          "final_price": 0,
          "categories": []
        }
      ],
      "stations_to": [
        {
          "id": "22",
          "name": "Moharam Bek",
          "city_id": 2,
          "city_name": "Alexandria",
          "arrival_at": "2026-07-10 10:00:00",
          "latitude": "31.178158",
          "longitude": "29.915599",
          "currency": "EGP",
          "price": 375,
          "original_price": 375,
          "final_price": 375,
          "categories": []
        }
      ],
      "pricing": [],
      "price_start_with": 375,
      "prices_start_with": {
        "original_price": 375,
        "final_price": 375,
        "offer_price": "0"
      },
      "available_seats": 0,
      "original_price": 375,
      "foreigner_price": 375
    },
    {
      "id": 236528,
      "gateway_id": "Distribusion",
      "currency": "EGP",
      "company": "GO Bus",
      "company_data": {
        "id": 47,
        "name": "GO Bus",
        "avatar": "",
        "bus_image": "",
        "pin": ""
      },
      "category": "FARE-1",
      "date": "2026-07-10",
      "time": "12:05 am",
      "date_time": "2026-07-10 00:05",
      "bus": {
        "id": 236528,
        "code": "Distribusion-236528",
        "category": "FARE-1",
        "salon": "FARE-1",
        "type": "bus",
        "seats_count": 0
      },
      "cities_from": [
        {
          "id": 1,
          "name": "Cairo",
          "latitude": "1",
          "longitude": "1",
          "price": 0
        }
      ],
      "cities_to": [
        {
          "id": 2,
          "name": "Alexandria",
          "latitude": "1",
          "longitude": "1",
          "price": 0
        }
      ],
      "stations_from": [
        {
          "id": "EGCAIBCN",
          "name": " Cairo NasrCity Station",
          "city_id": 1,
          "city_name": "Cairo",
          "arrival_at": "2026-07-10 20:35:00",
          "latitude": "30.0468889",
          "longitude": "31.316978",
          "currency": "EGP",
          "price": 0,
          "original_price": 0,
          "final_price": 0,
          "categories": []
        }
      ],
      "stations_to": [
        {
          "id": "EGALEALG",
          "name": "Moharam Bek",
          "city_id": 2,
          "city_name": "Alexandria",
          "arrival_at": "2026-07-11 00:05:00",
          "latitude": "31.178104",
          "longitude": "29.914984",
          "currency": "EGP",
          "price": 244.03,
          "original_price": 244.03,
          "final_price": 244.03,
          "categories": []
        }
      ],
      "pricing": [],
      "price_start_with": 244.03,
      "prices_start_with": {
        "original_price": 244.03,
        "final_price": 244.03,
        "offer_price": 0
      },
      "available_seats": 0,
      "original_price": 244.03,
      "foreigner_price": 244.03
    },
    {
      "id": 236529,
      "gateway_id": "Distribusion",
      "currency": "EGP",
      "company": "GO Bus",
      "company_data": {
        "id": 47,
        "name": "GO Bus",
        "avatar": "",
        "bus_image": "",
        "pin": ""
      },
      "category": "FARE-1",
      "date": "2026-07-10",
      "time": "12:50 am",
      "date_time": "2026-07-10 00:50",
      "bus": {
        "id": 236529,
        "code": "Distribusion-236529",
        "category": "FARE-1",
        "salon": "FARE-1",
        "type": "bus",
        "seats_count": 0
      },
      "cities_from": [
        {
          "id": 1,
          "name": "Cairo",
          "latitude": "1",
          "longitude": "1",
          "price": 0
        }
      ],
      "cities_to": [
        {
          "id": 2,
          "name": "Alexandria",
          "latitude": "1",
          "longitude": "1",
          "price": 0
        }
      ],
      "stations_from": [
        {
          "id": "EGCAICAS",
          "name": "Abd El Monim Riad",
          "city_id": 1,
          "city_name": "Cairo",
          "arrival_at": "2026-07-10 21:20:00",
          "latitude": "30.05023",
          "longitude": "31.23328",
          "currency": "EGP",
          "price": 0,
          "original_price": 0,
          "final_price": 0,
          "categories": []
        }
      ],
      "stations_to": [
        {
          "id": "EGALEALG",
          "name": "Moharam Bek",
          "city_id": 2,
          "city_name": "Alexandria",
          "arrival_at": "2026-07-11 00:50:00",
          "latitude": "31.178104",
          "longitude": "29.914984",
          "currency": "EGP",
          "price": 244.03,
          "original_price": 244.03,
          "final_price": 244.03,
          "categories": []
        }
      ],
      "pricing": [],
      "price_start_with": 244.03,
      "prices_start_with": {
        "original_price": 244.03,
        "final_price": 244.03,
        "offer_price": 0
      },
      "available_seats": 0,
      "original_price": 244.03,
      "foreigner_price": 244.03
    },
    "…12 more items"
  ],
  "pagination": {
    "total": 36,
    "lastPage": 3,
    "perPage": 15,
    "currentPage": 1,
    "nextPageUrl": "https://portal.wdenytravel.com/api/v1/buses/trips?page=2",
    "previousPageUrl": null
  }
}
```

### Search details

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/buses/trips/236510` |
| **Full URL** | `https://demo.safaria.travel/api/v1/buses/trips/236510?currency=EGP` |
| **Auth** | Bearer token required |

**Query parameters:**

| Parameter | Example |
|-----------|---------|
| `page` | 1 |
| `accept` |  |
| `currency` | EGP |

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |
| `Accept-Language` | `ar` \| `en` (app locale) |

**Saved responses:**

| HTTP | Scenario | Language | Error fields |
|------|----------|----------|--------------|
| `200` | Trips list | ar | — |
| `200` | Trip details | ar | — |
| `404` | Not found (HTML) | ar | — |

#### 200 — Trips list (ar)

```json
{
  "status": 200,
  "message": "Trips list",
  "errors": {},
  "data": [
    {
      "id": 290545,
      "gateway_id": "Tazcara",
      "company": "النورس للنقل البري",
      "company_data": {
        "name": "النورس للنقل البري",
        "avatar": "https://telefreik-app.test/storage/companies/40.png",
        "bus_image": "https://telefreik-app.test/assets/images/buses/default.jpeg",
        "pin": "https://telefreik-app.test/assets/images/pins/nowras.png"
      },
      "category": "VIP",
      "date": "2025-02-10",
      "time": "07:00 am",
      "date_time": "2025-02-10 07:00",
      "bus": {
        "id": 290545,
        "code": "النورس للنقل البري-290545",
        "category": "VIP",
        "salon": "vip",
        "type": "bus"
      },
      "cities_from": [
        {
          "id": 1,
          "name": "القاهره",
          "latitude": "",
          "longitude": "",
          "price": 0
        }
      ],
      "cities_to": [
        {
          "id": 2,
          "name": "الاسكندريه",
          "latitude": "",
          "longitude": "",
          "price": 0
        }
      ],
      "stations_from": [
        {
          "id": 985052,
          "city_id": 1,
          "city_name": "القاهره",
          "arrival_at": "2025-02-10 07:00:00",
          "name": "القللي",
          "latitude": "30.060136",
          "longitude": "31.243630",
          "price": 0,
          "original_price": 0,
          "final_price": 0,
          "categories": []
        }
      ],
      "stations_to": [
        {
          "id": 985053,
          "city_id": 2,
          "city_name": "الاسكندريه",
          "arrival_at": "2025-02-10 10:00:00",
          "name": "محرم بك",
          "latitude": "",
          "longitude": "",
          "price": 148.5,
          "original_price": 150,
          "final_price": 148.5
        }
      ],
      "pricing": [],
      "price_start_with": 148.5,
      "prices_start_with": {
        "original_price": 150,
        "final_price": 148.5,
        "offer": "1%"
      },
      "available_seats": 0
    },
    {
      "id": 291382,
      "gateway_id": "Tazcara",
      "company": "هاى جيت للنقل البرى والبحرى",
      "company_data": {
        "name": "هاى جيت للنقل البرى والبحرى",
        "avatar": "https://telefreik-app.test/storage/companies/29.png",
        "bus_image": "https://telefreik-app.test/assets/images/buses/default.jpeg",
        "pin": "https://telefreik-app.test/assets/images/pins/highjet.png"
      },
      "category": "Economy",
      "date": "2025-02-10",
      "time": "05:00 pm",
      "date_time": "2025-02-10 17:00",
      "bus": {
        "id": 291382,
        "code": "هاى جيت للنقل البرى والبحرى-291382",
        "category": "Economy",
        "salon": "economy",
        "type": "bus"
      },
      "cities_from": [
        {
          "id": 1,
          "name": "القاهره",
          "latitude": "",
          "longitude": "",
          "price": 0
        }
      ],
      "cities_to": [
        {
          "id": 2,
          "name": "الاسكندريه",
          "latitude": "",
          "longitude": "",
          "price": 0
        }
      ],
      "stations_from": [
        {
          "id": 989250,
          "city_id": 1,
          "city_name": "القاهره",
          "arrival_at": "2025-02-10 17:00:00",
          "name": "القللى",
          "latitude": "",
          "longitude": "",
          "price": 0,
          "original_price": 0,
          "final_price": 0,
          "categories": []
        },
        {
          "id": 989251,
          "city_id": 1,
          "city_name": "القاهره",
          "arrival_at": "2025-02-10 17:15:00",
          "name": "احمد حلمى",
          "latitude": "",
          "longitude": "",
          "price": 0,
          "original_price": 0,
          "final_price": 0,
          "categories": []
        }
      ],
      "stations_to": [
        {
          "id": 989252,
          "city_id": 2,
          "city_name": "الاسكندريه",
          "arrival_at": "2025-02-10 20:30:00",
          "name": "محرم بيك",
          "latitude": "",
          "longitude": "",
          "price": 118.8,
          "original_price": 120,
          "final_price": 118.8
        }
      ],
      "pricing": [],
      "price_start_with": 118.8,
      "prices_start_with": {
        "original_price": 120,
        "final_price": 118.8,
        "offer": "1%"
      },
      "available_seats": 0
    }
  ],
  "pagination": {
    "total": 2,
    "lastPage": 1,
    "perPage": 10,
    "currentPage": 1,
    "nextPageUrl": null,
    "previousPageUrl": null
  }
}
```

#### 200 — Trip details (ar)

```json
{
  "status": 200,
  "message": "Trip details",
  "errors": {},
  "data": {
    "id": 236510,
    "gateway_id": "BlueBus",
    "currency": "SAR",
    "company": "بلو باص",
    "company_data": {
      "id": 1,
      "name": "بلو باص",
      "avatar": "",
      "bus_image": "",
      "pin": ""
    },
    "category": "first8",
    "date": "2026-07-10",
    "time": "12:01 am",
    "date_time": "2026-07-10 00:01",
    "bus": {
      "id": 236510,
      "code": "BlueBus-236510",
      "category": "first8",
      "salon": "first8",
      "type": "bus",
      "seats_count": 0
    },
    "cities_from": [],
    "cities_to": [],
    "stations_from": [],
    "stations_to": [],
    "pricing": [],
    "price_start_with": 26.2,
    "prices_start_with": {
      "original_price": 26.2,
      "final_price": 26.2,
      "offer_price": "0"
    },
    "available_seats": 0,
    "original_price": 26.2,
    "foreigner_price": 26.2
  }
}
```

#### 404 — Not found (HTML) (ar)

_404 HTML page returned — stale example URL in Postman (`originalRequest` may point to a removed path)._

### Seats

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/buses/trips/236510/seats` |
| **Full URL** | `https://demo.safaria.travel/api/v1/buses/trips/236510/seats?from_city_id=1&to_city_id=2&from_location_id=46&to_location_id=22&date=2026-07-10` |
| **Auth** | Bearer token required |

**Query parameters:**

| Parameter | Example |
|-----------|---------|
| `from_city_id` | 1 |
| `to_city_id` | 2 |
| `from_location_id` | 46 |
| `to_location_id` | 22 |
| `date` | 2026-07-10 |

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |
| `Accept-Language` | `ar` \| `en` (app locale) |
| `Content-Type` | application/json |

**Saved responses:**

| HTTP | Scenario | Language | Error fields |
|------|----------|----------|--------------|
| `200` | Seat map | ar | — |
| `200` | Seat map | ar | — |
| `400` | Missing location IDs | ar | `from_location_id`, `to_location_id` |

#### 200 — Seat map (ar)

```json
{
  "status": 200,
  "message": "salons seats",
  "errors": {},
  "data": {
    "salon": {
      "id": 289921,
      "name": "Express",
      "rows": 13,
      "columns": 5,
      "direction": "ltr"
    },
    "seats_map": [
      {
        "seat_no": null,
        "class": "driver"
      },
      {
        "seat_no": null,
        "class": "space"
      },
      {
        "seat_no": null,
        "class": "space"
      },
      "…62 more items"
    ]
  }
}
```

#### 200 — Seat map (ar)

```json
{
  "status": 200,
  "message": "salons seats",
  "errors": {},
  "data": {
    "salon": {
      "id": 125723,
      "name": "",
      "rows": 12,
      "columns": 5,
      "direction": "ltr",
      "levels": 1
    },
    "seats_map": [
      {
        "id": null,
        "seat_no": null,
        "class": "space",
        "category": null,
        "level": 1
      },
      {
        "id": null,
        "seat_no": null,
        "class": "driver",
        "category": null,
        "level": 1
      },
      {
        "id": null,
        "seat_no": null,
        "class": "space",
        "category": null,
        "level": 1
      },
      "…57 more items"
    ]
  }
}
```

#### 400 — Missing location IDs (ar)

```json
{
  "status": 400,
  "message": "حقل from location id مطلوب.",
  "errors": {
    "from_location_id": "حقل from location id مطلوب.",
    "to_location_id": "حقل to location id مطلوب."
  },
  "data": {}
}
```

### Create Ticket

| | |
|---|---|
| **Method** | `POST` |
| **Path** | `/buses/trips/236437/create-ticket` |
| **Full URL** | `https://demo.safaria.travel/api/v1/buses/trips/236437/create-ticket` |
| **Auth** | Bearer token required |

**Body (JSON):**

```json
{
  "from_city_id": 1,
  "to_city_id": 2,
  "from_location_id": "50",
  "to_location_id": "22",
  "date": "2026-07-29",
  "seats": [
    {
      "seat_type_id": "3",
      "seat_id": "3"
    }
  ],
  "payment_method": "myfatoorah",
  "currency": "EGP"
}
```

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |
| `Accept-Language` | `ar` \| `en` (app locale) |
| `Content-Type` | application/json |

**Saved responses:**

| HTTP | Scenario | Language | Error fields |
|------|----------|----------|--------------|
| `200` | Order details | ar | — |
| `401` | Unauthenticated | ar | — |
| `500` | Server error | ar | — |
| `200` | Order created | ar | — |
| `200` | Order created | ar | — |

#### 200 — Order details (ar)

```json
{
  "status": 200,
  "message": "Order details",
  "errors": {},
  "data": {
    "id": 1,
    "gateway_order_id": 186263,
    "gateway_id": "WEBUS",
    "total": "295.00",
    "payment_data": {
      "status": "pending"
    },
    "station_from": {
      "id": 1,
      "name": "Lebanon Square _ Mohandessin",
      "latitude": "31.194320354715924",
      "longitude": "30.060248340581786",
      "price": null
    },
    "station_to": {
      "id": 5,
      "name": "Dahab Station",
      "latitude": "34.51482913932954",
      "longitude": "28.49466500751688",
      "price": null
    },
    "date": "2023-02-15T01:00:00.000000Z"
  }
}
```

#### 401 — Unauthenticated (ar)

```json
{
  "status": 401,
  "message": "Unauthenticated",
  "errors": {},
  "data": {}
}
```

#### 500 — Server error (ar)

```json
{
  "message": "Undefined array key \"url\"",
  "exception": "ErrorException",
  "file": "/var/www/wadeny/packages/transport/src/Actions/PayMobPayAction.php",
  "line": 24
}
```

#### 200 — Order created (ar)

```json
{
  "status": 200,
  "message": "order created",
  "errors": {},
  "data": {
    "number": "000001454",
    "id": 1454,
    "trip_id": "125723",
    "gateway_order_id": "1204297",
    "company_data": {
      "name": "بلو باص",
      "avatar": "",
      "bus_image": "",
      "pin": ""
    },
    "status": "Pending",
    "status_code": "pending",
    "gateway_id": "BlueBus",
    "company_name": "بلو باص",
    "category": "first8",
    "can_be_cancel": true,
    "trip_type": "Buses",
    "is_confirmed": 0,
    "review": null,
    "can_review": false,
    "payment_data": {
      "status": "Pending",
      "status_code": "pending",
      "invoice_id": 6931675,
      "gateway": "Myfatoorah",
      "invoice_url": "https://demo.MyFatoorah.com/KWT/ia/…",
      "data": {
        "notes": ""
      }
    },
    "invoice_url": "https://portal.wdenytravel.com/orders/1454/invoice/…",
    "station_from": {
      "id": "938",
      "station_id": "938",
      "name": "رمسيس",
      "city_id": 1,
      "city_name": "القاهره",
      "latitude": "30.063437",
      "longitude": "31.252121",
      "arrival_at": "2026-07-10 06:15 am"
    },
    "station_to": {
      "id": "945",
      "station_id": "945",
      "name": "محرم بك",
      "city_id": 2,
      "city_name": "الاسكندريه",
      "latitude": "31.178158",
      "longitude": "29.915599",
      "arrival_at": "2026-07-10 10:00 am"
    },
    "tickets": [
      {
        "id": 2051,
        "seat_number": "16",
        "price": "19.56"
      }
    ],
    "date": "2026-07-10",
    "date_time": "2026-07-10 12:01 AM",
    "payment_url": "https://portal.wdenytravel.com/api/v1/buses/orders/1454/…",
    "cancel_url": "https://portal.wdenytravel.com/api/v1/buses/orders/1454/cancel",
    "original_tickets_totals": "EGP 19.56",
    "discount": "EGP 0.00",
    "wallet_discount": "EGP 0.00",
    "tickets_totals_after_discount": "EGP 19.56",
    "payment_fees": "EGP 1.37",
    "total": "EGP 20.93",
    "currency": "SAR"
  }
}
```

#### 200 — Order created (ar)

```json
{
  "status": 200,
  "message": "order created",
  "errors": {},
  "data": {
    "number": "000001455",
    "id": 1455,
    "trip_id": "125723",
    "gateway_order_id": "1204737",
    "company_data": {
      "name": "بلو باص",
      "avatar": "",
      "bus_image": "",
      "pin": ""
    },
    "status": "Pending",
    "status_code": "pending",
    "gateway_id": "BlueBus",
    "company_name": "بلو باص",
    "category": "first8",
    "can_be_cancel": true,
    "trip_type": "Buses",
    "is_confirmed": 0,
    "review": null,
    "can_review": false,
    "payment_data": {
      "status": "Pending",
      "status_code": "pending",
      "invoice_id": 6933118,
      "gateway": "Myfatoorah",
      "invoice_url": "https://demo.MyFatoorah.com/KWT/ia/…",
      "data": {
        "notes": ""
      }
    },
    "invoice_url": "https://portal.wdenytravel.com/orders/1455/invoice/…",
    "station_from": {
      "id": "938",
      "station_id": "938",
      "name": "رمسيس",
      "city_id": 1,
      "city_name": "القاهره",
      "latitude": "30.063437",
      "longitude": "31.252121",
      "arrival_at": "2026-07-10 06:15 am"
    },
    "station_to": {
      "id": "945",
      "station_id": "945",
      "name": "محرم بك",
      "city_id": 2,
      "city_name": "الاسكندريه",
      "latitude": "31.178158",
      "longitude": "29.915599",
      "arrival_at": "2026-07-10 10:00 am"
    },
    "tickets": [
      {
        "id": 2052,
        "seat_number": "16",
        "price": "280.00"
      }
    ],
    "date": "2026-07-10",
    "date_time": "2026-07-10 12:01 AM",
    "payment_url": "https://portal.wdenytravel.com/api/v1/buses/orders/1455/…",
    "cancel_url": "https://portal.wdenytravel.com/api/v1/buses/orders/1455/cancel",
    "original_tickets_totals": "EGP 280.00",
    "discount": "EGP 0.00",
    "wallet_discount": "EGP 0.00",
    "tickets_totals_after_discount": "EGP 280.00",
    "payment_fees": "EGP 19.60",
    "total": "EGP 299.60",
    "currency": "EGP"
  }
}
```

### cancel

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `*(not configured)*` |
| **Full URL** | `*(not configured)*` |
| **Auth** | Bearer token required |

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |
| `Accept-Language` | `ar` \| `en` (app locale) |

## Currencies

| # | Method | Path | Name |
|---|--------|------|------|
| 1 | `GET` | `/flights/iata` | Currencies |

### Currencies

| | |
|---|---|
| **Method** | `GET` |
| **Path** | `/flights/iata` |
| **Full URL** | `https://demo.safaria.travel/api/v1/flights/iata` |
| **Auth** | Bearer token required |

**Query parameters:**

| Parameter | Example |
|-----------|---------|
| `search` | CAI |

**Headers:**

| Header | Value |
|--------|-------|
| `Accept` | application/json |
| `Accept-Language` | `ar` \| `en` (app locale) |

## Collection issues

The following inconsistencies exist in the Postman collection and may not reflect the real API:

| Item | Issue |
|------|-------|
| Content → New Request | No URL configured (empty request) |
| Private → Show Trip Details | URL points to `/flights/airports/search` instead of a private trip endpoint |
| Currencies | Named "Currencies" but URL is `/flights/iata?search=CAI` — likely copy-paste error |
| Profile → Wallet / Orders (GET) | Postman copies form-data bodies from other requests — real API expects no body on these GET calls |
| Buses saved examples | Some `originalRequest` URLs still point to legacy `/api/transports/*` paths — response bodies are valid; request snapshots are stale |
| Buses → Create Ticket (500) | Known backend bug in `PayMobPayAction` (`Undefined array key "url"`) — not a client contract |
| Buses → Search details (404 HTML) | Saved example returned an HTML 404 page — likely captured against a removed trip ID |

Nested items under Flights → Search (One Way, Round Trip, Multi City) and under Buses folders are **saved response examples**, not separate API endpoints. They all call the same endpoint as their parent request.

Saved responses documented under Auth, Profile, and Buses (and other folders when using `--responses=all`) are **real response examples** attached to the parent request — not separate endpoints.
