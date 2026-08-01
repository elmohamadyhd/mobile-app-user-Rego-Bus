# Push Notifications — Setup Checklist

> آخر تحديث: 2026-08-01  
> استخدم القائمة دي لما ترجع تكمل شغل الإشعارات. علّم `[x]` لكل بند لما يخلص.

مرجع التصميم الأصلي: `docs/superpowers/specs/2026-07-29-notifications-feature-design.md`

---

## الحالة العامة

| المنصة | الكود في المشروع | الإعداد الخارجي | جاهز للاختبار؟ |
|--------|------------------|-----------------|----------------|
| **Android** | ✅ تقريباً كامل | ⚠️ تحقق من السيرفر | نعم — على جهاز حقيقي |
| **iOS** | ✅ الملفات الأساسية | ❌ لسه ناقص | لا — لازم Mac + APNs |
| **Backend** | — | ❓ غير معروف | لازم FCM من السيرفر |

**Bundle / Package ID الموحّد:** `com.teleferik`  
(يطابق Play Store وملفات Firebase الحالية)

---

## ✅ اتعمل في المشروع (مش محتاج تعيده)

### Flutter / Dart
- [x] `firebase_core` + `firebase_messaging` في `pubspec.yaml`
- [x] تهيئة Firebase في `lib/main.dart` → `initializeFirebasePush()`
- [x] Background handler في `lib/core/push/firebase_push_setup.dart`
- [x] `FcmPushTokenProvider` — توكن FCM حقيقي
- [x] `fcmRegistrarProvider` — مزامنة التوكن مع `PUT /profile/firebase/token` عند تسجيل الدخول
- [x] صندوق الإشعارات داخل التطبيق (`/profile/notifications`)

### Android
- [x] `android/app/google-services.json`
- [x] Google Services plugin في Gradle
- [x] `applicationId = com.teleferik`
- [x] صلاحية `POST_NOTIFICATIONS` في `AndroidManifest.xml`

### iOS (ملفات فقط — البناء لسه على Mac)
- [x] مجلد `ios/` مُنشأ
- [x] `ios/Runner/GoogleService-Info.plist`
- [x] `PRODUCT_BUNDLE_IDENTIFIER = com.teleferik`
- [x] `UIBackgroundModes` → `remote-notification` في `Info.plist`
- [x] `ios/Runner/Runner.entitlements` (`aps-environment: development`)
- [x] `AppDelegate.swift` → `registerForRemoteNotifications()`

---

## ⬜ Android — تحقق قبل الإطلاق

- [ ] **اختبار على جهاز حقيقي** (الإيميوليتر غير موثوق مع FCM)
- [ ] تسجيل دخول بحساب حقيقي (مش Guest) والموافقة على إذن الإشعارات
- [ ] إرسال إشعار تجريبي من Firebase Console → **Messaging**
- [ ] التأكد إن التوكن بيوصل للسيرفر (`PUT /profile/firebase/token`)
- [ ] **Release signing** — حالياً Release يستخدم debug keys (`android/app/build.gradle.kts`)

---

## ⬜ iOS — لازم تكمله على Mac

### Firebase Console
- [ ] رفع **APNs Authentication Key** (ملف `.p8`)  
  المسار: Firebase → Project Settings → Cloud Messaging → Apple app configuration  
  بدون الخطوة دي **iOS push مش هتشتغل**

### Apple Developer
- [ ] App ID `com.teleferik` فيه capability **Push Notifications**
- [ ] Provisioning Profile محدّث يدعم Push

### Xcode (`ios/Runner.xcworkspace`)
- [ ] اختيار **Team** للتوقيع (Signing & Capabilities)
- [ ] التأكد إن **Push Notifications** capability ظاهرة
- [ ] التأكد إن **Background Modes → Remote notifications** مفعّلة
- [ ] بناء وتشغيل على **iPhone حقيقي** (Simulator محدود للـ push)

### قبل App Store / TestFlight
- [ ] تغيير `ios/Runner/Runner.entitlements`:
  ```xml
  <key>aps-environment</key>
  <string>production</string>
  ```
  (حالياً `development` — للتطوير فقط)

---

## ⬜ Backend (السيرفر)

- [ ] السيرفر يبعت الإشعارات عبر **FCM HTTP v1** أو **Firebase Admin SDK**
- [ ] يستخدم الـ `firebase_token` المسجّل من التطبيق (مش UUID التثبيت القديم)
- [ ] اختبار end-to-end: حدث من السيرفر → إشعار يوصل للجهاز

---

## ⬜ اختياري — مش في النطاق الحالي

هذه كانت **خارج النطاق** في التصميم الأصلي؛ أضفها لو محتاجها لاحقاً:

- [ ] عرض الإشعار لما التطبيق **مفتوح** (foreground) — محتاج `flutter_local_notifications` أو معالجة يدوية
- [ ] التنقل عند الضغط على الإشعار (deep links)
- [ ] إعدادات تفعيل/إلغاء الإشعارات من داخل التطبيق
- [ ] iOS Google Sign-In (لو هتضيف تسجيل Google على iOS)

---

## ملفات مهمة — مرجع سريع

| الملف | الغرض |
|-------|--------|
| `lib/main.dart` | `initializeFirebasePush()` |
| `lib/core/push/firebase_push_setup.dart` | تهيئة Firebase + background handler |
| `lib/features/notifications/presentation/providers/fcm_registrar.dart` | مزامنة التوكن مع الـ API |
| `lib/features/notifications/presentation/providers/fcm_push_token_provider.dart` | جلب توكن FCM |
| `android/app/google-services.json` | إعداد Firebase لـ Android |
| `ios/Runner/GoogleService-Info.plist` | إعداد Firebase لـ iOS |
| `ios/Runner/Runner.entitlements` | صلاحية APNs |

---

## أوامر مفيدة

```bash
# dependencies (استخدم السكربت مش pub get العادي على Windows/Android)
./tool/pub-get.ps1

# تحليل واختبارات الإشعارات
flutter analyze
flutter test test/features/notifications/

# Android — جهاز حقيقي
flutter run

# iOS — من Mac فقط
cd ios && pod install   # لو المشروع رجع لـ CocoaPods
flutter run
```

---

## ملاحظات

1. **Windows:** تقدر تبني وتختبر Android بس. iOS لازم Mac.
2. **Package ID:** لو حبيت ترجع لـ `com.safaria.travel`، لازم تضيف التطبيق في Firebase Console وتنزّل ملفات config جديدة.
3. **Guest mode:** التوكن بيتسجّل بس لما المستخدم مسجّل دخول (مش ضيف).
