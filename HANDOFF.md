# WIINZ — Project Handoff (for a fresh chat session)

> Read this first. It's the source of truth for picking up work. Also read
> `HANDOFF.md` alongside the memory index at
> `C:\Users\HP\.claude\projects\D--Claude-WIINZ-App-2026\memory\MEMORY.md`.

## What WIINZ is
Waste-collection / recycling rewards app for Algeria (Arabic, RTL). Citizens drop
recyclable **bottles** at physical **collection points**, scan a QR there to earn
**"Wz" points**, and redeem points for **gifts** (which land in **مكافأتي**). Built
from a Claude Design prototype (the design handoff lives in
`Claud Code Handoff Package/extracted/design_handoff_wiinz_app/README.md` — that
README is the visual/behavior source of truth for colors, copy, layout).

## Repo layout (root: `D:\Claude\WIINZ App 2026`)
- `wiinz_app/` — Flutter app (Dart 3.12 / Flutter 3.44). All screens + logic.
- `wiinz_server/` — Node/Express + lowdb JSON backend. `server.js` + `db_defaults.js`.
  Runs on **port 4000**. Dashboard static files in `wiinz_server/dashboard/`.
- `WIINZ.apk` — last exported phone build (may be stale after recent edits; rebuild before sharing).
- `Claud Code Handoff Package/` — the Claude Design prototype + README.

## Tech / stack choices
- **Backend**: Express + lowdb (`data/db.json`). Auth = JWT (bcrypt). No real auth on
  `/api/admin/*` (local-dev only). Seeds from `db_defaults.js`; migrations at top of `server.js`.
- **App base URL**: `lib/core/api_client.dart` → `ApiClient.baseUrl`. Currently
  `http://192.168.1.5:4000/api` (the dev PC's LAN IP, works for BOTH the phone and the
  emulator). For emulator-only you could use `http://10.0.2.2:4000/api`.
  ⚠️ RECURRING GOTCHA: the PC's LAN IP changes (was .2, now .5). When the phone can't sign
  up / reach the backend, check the current IP (`Get-NetIPAddress -AddressFamily IPv4`),
  update this constant, and rebuild the APK. Also ensure the backend is RUNNING and the
  firewall allows port 4000.
- **Map**: MapLibre GL (`maplibre_gl`) + OpenFreeMap style
  `https://tiles.openfreemap.org/styles/liberty` (OSM, no API key). Location via `geolocator`.
- **QR**: `mobile_scanner` (scanning, restricted to QR + noDuplicates + errorBuilder to
  avoid a native null-ref crash) and `qr_flutter` (rendering).
- **Icons**: `material_symbols_icons` mapped by name in `lib/widgets/ui.dart` (`wIcon`/`mi`).
  Brand/social icons via `font_awesome_flutter`. Fonts: Cairo + Noto Sans Arabic via `google_fonts`.
- **Other pkgs**: `flutter_riverpod`, `go_router`, `shared_preferences`, `http`,
  `url_launcher`, `permission_handler`.
- Design tokens (colors/gradients/shadows/text styles) in `lib/theme/app_theme.dart` (class `C`).

## App structure (`wiinz_app/lib`)
- `main.dart` — GoRouter: /splash /login /signup /home /map /scan /perks /gifts /more. RTL-wrapped.
- `core/`: `api_client.dart` (all HTTP), `session.dart` (auth+user+config Notifier),
  `notifications.dart` (unread/shining-dot + list).
- `models/models.dart`: WiinzUser, CollectionPoint, Coupon, Gift(+Store), HeroGift,
  AppNotification, Referral, HistoryItem, LeaderRow, AppConfig, AdBanner, MyGift, Store.
- `screens/`: splash, auth/auth_screen (login+signup one screen, toggles), home/home_screen,
  map/map_screen, scan/scan_screen, perks/perks_screen (=مكافأتي), gifts/gifts_screen,
  more/more_screen, overlays/{overlays.dart (stats+notifs sheets), dialogs.dart (confirm,
  bottle stepper, scan success, code popup)}.
- `widgets/`: ui.dart (mi/hexColor/GradientButton/showToast/storeLogo), bottom_nav.dart, headers.dart.

## Core data model & flows (backend)
- **Users**: full profile (name/phone/email/wilaya/commune/gender/birthdate), `points`,
  auto sequential `qrCode` = `inviteCode` = `cardCode` = `WIIN-U-00x`, tier derived from points.
- **Collection points**: `code` = `WIIN-P-00x`, lat/lng, hours (24h fmt "08:00 - 20:00"),
  phone, rating, open, accepts, `logo` (base64 dataURI or null).
- **Gifts**: `code` = `WIIN-G-00x`, cost, category, icon/colors, + **store info**
  (storeName/storeAddress/storePhone/storeLat/storeLng/logo). Plus a single `heroGift`.
- **Config** (admin-editable): `pointsPerBottle` (=5), silver/goldGoal, referral/video rewards, videosPerDay, userSeq.
- **Locations**: `wilayas` (list) + `communesByWilaya` (map wilaya→[communes]). Signup commune depends on chosen wilaya.
- **Connected QR flows** (ALL verified working):
  - User scans point (`/scan/validate` then `/scan` with `bottles`) → points = bottles×pointsPerBottle×eventMultiplier.
  - Collect-point owner scans user's `WIIN-U` code from the dashboard "scan-user" tool (with bottle count) → credits user.
  - Claim gift → confirm dialog → creates a **pending redemption** (`WIIN-R-xxxx`) shown in **مكافأتي**.
  - Store owner enters the `WIIN-R` code in the dashboard "redeem-gift" tool → gift redeemed → disappears from مكافأتي.
  - User can "رد النقاط" (refund) their own pending gift (confirm dialog) → points back, removed.
- **Notifications**: global list, **targetable** by gender/wilaya/commune/age-range (`filter` field);
  `GET /api/notifications` filters per authenticated user. App polls every 8s → in-app banner + shining dot.
- **Support tickets**: `POST /api/support` (from app), `GET/DELETE /api/admin/support` (dashboard).
- **Events / Ads**: admin-managed, each has an `image` (base64). Ad shown in home banner.

## Admin dashboard (`http://localhost:4000/dashboard`, RTL, vanilla JS)
Sections: overview, users (shows name/phone/gender/birthdate/wilaya/commune/qr/points + edit-qr/points/delete),
collection points (CRUD + Leaflet map picker + logo upload), coupons, gifts (CRUD + store fields + logo,
+ hero editor), **أكواد QR والمسح** (QR image galleries + scan-user tool + redeem-gift tool + claims table),
events (CRUD+image), ads (CRUD+image), notifications (broadcast **with targeting** gender/wilaya/commune/age),
**support** (tickets), config (points/tiers + **wilaya→commune lists editor**), data/logs.
Image uploads are base64 dataURIs (≤400KB) via `readImage()`; forms driven by `SCHEMAS`/`fieldHtml`.
Note: background auto-refresh skips re-rendering `qrcodes`+`config` sections so their inputs aren't wiped.

## How to run
1. Backend: `cd wiinz_server && node server.js` (port 4000; delete `data/db.json` first for a clean reseed).
2. Emulator AVD `WIINZ_Pixel7`:
   `emulator -avd WIINZ_Pixel7 -no-snapshot -gpu swiftshader_indirect`
   (PATH-add `%LOCALAPPDATA%\Android\Sdk\emulator` + `platform-tools`). Software GL is UNSTABLE under
   MapLibre+camera load — it crashes on the scan/camera screen sometimes. That's an emulator issue, not the app.
   Camera works on real hardware.
3. App: `flutter run -d emulator-5554` (PATH-add `/d/flutter/flutter/bin`).
   Mock GPS: `adb emu geo fix 3.0588 36.7538`. Disable stylus popup: `adb shell settings put secure stylus_handwriting_enabled 0`.
4. Phone APK: `flutter build apk --release` → `build/app/outputs/flutter-apk/app-release.apk`
   → copy to `WIINZ.apk`. Needs: phone on same Wi-Fi as PC (192.168.1.2), backend running,
   Windows Firewall allowing port 4000 (`New-NetFirewallRule -DisplayName "WIINZ dev 4000" -Direction Inbound -LocalPort 4000 -Protocol TCP -Action Allow` as admin).
   Manifest already has `usesCleartextTraffic=true` + camera/location perms.

## Conventions
- Arabic RTL everywhere; use `cairo()`/`noto()` text helpers + `C.*` colors from theme.
- Icons via `mi('name')`; add new names to the `_icons` map in `ui.dart` (they're compile-time `Symbols.*`).
- Money/points shown as "N Wz". Store logos via `storeLogo(dataUri, size)`.
- Keep verification light (user preference): compile-check via `flutter analyze`, avoid heavy emulator
  screenshot loops unless asked. The emulator is flaky under GL load.
- Windows gotcha: Kotlin incremental-cache lock can fail builds → `kotlin.incremental=false` already set
  in `android/gradle.properties`. Port 4000 often held by stray node — free via
  `Get-NetTCPConnection -LocalPort 4000 -State Listen | %{Stop-Process -Id $_.OwningProcess -Force}`.
- `.claude/settings.json` has `permissions.defaultMode: bypassPermissions` (user opted in).
- Demo users seeded via curl have garbled Arabic names (shell encoding); real on-device signups are fine.

## Status: ALL requested edits are implemented and `flutter analyze` passes (0 errors; ~10 info/lint only).
> LESSON: `flutter analyze` (and grepping its output) can MISS errors that a real `flutter build`
> catches — e.g. const-map duplicate keys, cross-file type mismatches, package API type changes.
> Before declaring a batch done or deploying, run an actual `flutter run`/`flutter build` and read
> the compiler output, not just `analyze`.
Most flows verified on emulator (auth incl. date picker + dependent communes, home card peek + shining bell,
gifts confirm→مكافأتي, dashboard tools, backend via curl). Scan camera + bottle-stepper is code-complete and
backend-verified; visual camera test is best done on the real phone (emulator GL crashes on camera).

## ⚠️ CURRENT ISSUE (investigate first tomorrow)
The app is **crashing** on the emulator (reported at end of last session, after the batch-2
edits were deployed via `flutter run`). Not yet diagnosed. Likely suspects to check in order:
1. Emulator software-GL instability under MapLibre/camera (known flaky on this machine) — try a
   fresh cold boot; test on the real phone where GL is stable.
2. A runtime (not compile) error in the new code — run `flutter run` and read the console/logcat
   for the Dart exception + stack (`adb logcat | grep -i flutter`). Compile is clean (analyze 0 errors).
   Prime suspects among new code: notification poll Timer / `_showIncoming` SnackBar margin math on
   home; `storeLogo` base64 decode; FaIcon/about sheet; MapLibre.
3. Backend dropped mid-session twice (port 4000 freed) — if the app can't reach it, it may surface as
   errors; ensure `node server.js` is running.
Reproduce, capture the actual exception, then fix.

## Test account (already seeded, ~300 Wz)
email `test@wiinz.com` / password `123456` (name Mahi, WIIN-U-002, الجزائر/بلكور). Backend must be running.

## Pending / next
- **User asked to confirm before exporting a new APK** — do NOT rebuild/share the APK until the user says so.
- Optional: verify the just-added batch on device (support sheet, about+socials, store info in code popup,
  notification realtime banner, wilaya→commune dashboard editor, image uploads) — user prefers minimal verification.
- If reseeding the DB for the new schema (store fields, communesByWilaya, support), delete `wiinz_server/data/db.json`
  before starting the server. Existing db.json auto-migrates missing keys but keeps old point `hours` until edited.

## Recent change batch (this session) — all done
Camera crash guard (qr-only + errorBuilder); date-picker big green buttons; القوارير→القارورات; home card peek
(viewportFraction .92) + unclipped card shadows; hero محدود badge un-clipped; realtime notification banner+dot;
gifts labels (استلام / تأكيد الاستلام / تأكيد) + per-gift store info; مكافأتي code popup "تم الاستلام" + bigger
verify text + store card + "موقع المتجر" maps button + "استرجاع نقاط…"; profile: support ticket sheet + about
sheet (WIIN ALGERIA + FB/IG/YT/LinkedIn/TikTok); signup wilaya→dependent communes; dashboard: image uploads
(points/gifts/events/ads/hero), per-wilaya commune editor, commune in notif targeting, user columns, support section.
