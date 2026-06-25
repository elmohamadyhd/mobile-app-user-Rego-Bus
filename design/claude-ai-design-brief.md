# REGO BUSES — Design Brief for claude.ai/design

Paste the **Master brief** once at the start of a claude.ai/design session, then request screens
using the **Per-screen prompts** (one batch or one screen at a time).

Source of truth: `docs/superpowers/specs/2026-06-25-rego-buses-app-screens-design.md`.

---

## MASTER BRIEF (paste first)

> **Product:** REGO BUSES — an Arabic-first, multi-modal travel booking app (intercity buses,
> flights, and private transfers) with an in-app wallet and customer support. Audience: Arabic
> speakers across the MENA region. Every screen is **Arabic, right-to-left (RTL)**, with
> Arabic-Indic numerals (٠١٢٣٤٥٦٧٨٩) and Egyptian-pound pricing (ج.م).
>
> **Art direction — "Skyline":** modern, premium, energetic travel app. The signature is an
> **immersive blue gradient hero** at the top of key screens that **curves at its bottom corners**,
> with a **white card that floats over it** (overlapping upward). Generous rounded corners, soft
> shadows, lots of breathing room. Think Omio / Hopper polish.
>
> **Brand colors:**
> - Primary blue `#1464EC`, dark `#0E50C7`, deepest `#0A3FA3`
> - Hero gradient: 160° from `#1D6FF2` → `#0E50C7` → `#0A3FA3`
> - Amber accent `#F0B256` (dark `#D98A2B`) — used sparingly for highlights, offers, the "to" pin
> - Surface `#F4F6FB`, cards white, ink `#141831`, muted text `#8A90A6`, hairlines `#EEF1F6`
>
> **Type:** Tajawal (Arabic + Latin). Headlines 800 weight, body 400/500.
>
> **Shape & depth:** card radius 24px, inputs 15px, pills fully rounded. Soft blue-tinted shadows
> (e.g. `0 18px 40px -18px rgba(14,80,199,.35)`). Decorative translucent circles ("blobs") inside
> heroes.
>
> **Icons:** clean **outline** icons (Tabler style). No emoji.
>
> **Device:** render each screen inside an iOS phone frame, 320px-ish wide, status bar showing 9:41.
>
> **Signature components (reuse across screens):**
> - Blue hero with rounded bottom + translucent decorative circles
> - Floating white card overlapping the hero upward
> - Segmented transport tabs: باص / طيران / نقل (active tab white pill on light track)
> - From→To field block with a circular **swap** button on the side; "from" uses a blue location
>   pin, "to" uses an amber map pin, separated by a hairline
> - Primary button: solid blue, soft glow shadow; amber variant for wallet/offers
> - Floating bottom navigation bar (Home / Tickets / [raised search FAB] / Wallet / Profile)
> - OTP: 4 separate rounded boxes; filled boxes tinted blue
> - Popular-destination cards: small colored cards (blue / amber) with city + "from X ج.م"
>
> Keep all of the above consistent. I'll ask for screens next.

---

## PER-SCREEN PROMPTS

### Batch 1 — Auth (7)
1. **Splash** — full blue gradient screen, centered white "REGO BUSES" wordmark (BUSES in amber), a bus icon in a translucent rounded square, tagline "كل الباصات.. منصة واحدة", three loading dots at the bottom.
2. **Onboarding** — white screen, large circular illustration area (blue-tint circle with a big bus icon + small amber/blue accent dots), title "احجز رحلتك بكل سهولة", subtitle, 3 progress dots (middle active), "تخطّي" top-left, a circular next FAB bottom-left.
3. **Login** — short blue hero ("أهلاً بعودتك 👋" / "سجّل الدخول للمتابعة") with a floating white card: phone-or-email input, password input with eye toggle, "نسيت كلمة المرور؟" link, blue "تسجيل الدخول" button, "أو تابع عبر" divider, Google/Facebook/Apple buttons, and "ليس لديك حساب؟ أنشئ حساباً" pinned at bottom.
4. **Register** — blue hero ("إنشاء حساب جديد"), floating card: full name, phone with +20 country chip, email, password fields, blue "إنشاء الحساب" button, "تسجيل الدخول" link at bottom.
5. **OTP verify** — back arrow appbar, blue-tint icon circle, "أدخل رمز التحقق", subtitle with the phone number, 4 OTP boxes (3 filled, 1 active), resend timer "٠:٥٩", blue "تأكيد" button.
6. **Forgot password** — back appbar, amber-tint lock illustration circle, "نسيت كلمة المرور؟", phone input with +20 chip, blue "إرسال الرمز" button.
7. **New password** — back appbar, blue-tint shield illustration, new-password + confirm-password fields, blue "حفظ كلمة المرور" button.

### Batch 2 — Home & Bus (6)
8. **Home** — blue hero ("أهلاً، أحمد" + bell, headline "احجز رحلتك بضغطة واحدة"), floating search card with transport tabs, From (القاهرة) → To (الإسكندرية) with swap button, blue "ابحث عن رحلة" button; below: "وجهات شهيرة" cards (الأقصر، أسوان); floating bottom nav.
9. **Trip results** — appbar with route summary (القاهرة → الإسكندرية, date) + filter icon; sort chips (الأوقات / الأرخص / المقاعد); list of trip cards: carrier name + logo, departure→arrival times, duration, price ج.م, seats-left badge, "اختر" button.
10. **Trip details** — carrier header, timeline of departure/arrival stations & times, bus amenities chips (واي فاي، تكييف، مقابس), price summary, "اختيار المقاعد" button.
11. **Seat selection** — bus seat map (driver, aisle, rows), legend (متاح / محجوز / مختار), selected seats summary + total, "متابعة" button.
12. **Passenger & confirm** — selected trip summary, passenger name/phone inputs, payment method (wallet/card), price breakdown, "تأكيد الحجز" button.
13. **E-ticket** — success header, boarding-pass style ticket with QR code, route/seat/date, perforated edge, "تحميل" / "مشاركة" actions.

### Batch 3 — Flights (6)
14. **Flight search** — tabs on طيران; trip type (ذهاب / ذهاب وعودة / متعدد), From/To airports with swap, dates, passengers & cabin class selector, "بحث عن رحلات" button.
15. **Flight results** — route + date header, filter/sort; flight cards: airline, depart→arrive times, duration + stops, price, "اختيار".
16. **Fare bundles** — chosen flight summary, bundle cards (lite / flex) with included/excluded items (bag, change, refund), price per bundle, select.
17. **Passenger details** — passenger form: name, passport, nationality, DOB; multiple-passenger accordion; "متابعة".
18. **Hold / review** — full itinerary review, fare summary, hold timer, "تثبيت الرحلة" / proceed to payment.
19. **Payment** — amount, pay-with wallet/card, card form or wallet balance, "ادفع الآن" button, secure note.

### Batch 4 — Transfer & Wallet (4)
20. **Transfer search** — map background with pickup/dropoff pins, From/To coordinate fields, one-way/round toggle, date & time, "اطلب سيارة" button.
21. **Transfer confirm** — route on map, vehicle type cards, fare estimate, pickup time, "تأكيد الطلب".
22. **Wallet** — gradient balance card (٣٤٠٫٥٠ ج.م) with "شحن" + "السجل" actions, transaction list (credit/debit rows with icons, amounts colored).
23. **Top-up** — amount entry with quick chips (٥٠ / ١٠٠ / ٢٠٠), payment method, "اشحن المحفظة" amber button.

### Batch 5 — Support & Profile (7)
24. **Tickets list** — "تذاكر الدعم", list of tickets with status badges (مفتوحة / مغلقة), last message preview, + new button.
25. **Ticket chat** — conversation thread (user vs support bubbles), attachment chip, message input with send button.
26. **New ticket** — title, section/category dropdown, description textarea, attach file, "إرسال" button.
27. **Profile** — avatar + name + phone header, menu rows (طلباتي، العناوين، المحفظة، اللغة، الإعدادات، المساعدة، تسجيل الخروج).
28. **Edit profile** — avatar with camera badge, name/email/phone/alt-phone fields, "حفظ التغييرات".
29. **Address book** — saved locations list (home/work/custom with map-pin icons + coordinates), add-new button, edit/delete.
30. **Settings** — language (عربي/English), notifications toggles, change password, privacy/terms links, delete account, app version.

### Batch 6 — Content & Notifications (4, optional)
31. **Notifications** — list of notification cards (booking, offer, system) with icons + timestamps, swipe/delete.
32. **Posts/blog** — banner + category chips, article cards with thumbnail + title + excerpt.
33. **Post detail** — hero image, title, body text, share.
34. **FAQ** — accordion list of questions grouped by category.

---

### Tip
If claude.ai/design drifts from the look, paste this reminder:
> Keep the Skyline style: blue gradient hero with curved bottom + floating white card, brand blue
> `#1464EC` + amber `#F0B256`, Tajawal font, Arabic RTL, outline icons, soft rounded cards.
