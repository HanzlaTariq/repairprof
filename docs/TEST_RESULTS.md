# Verification results

Build/test date: 4 October 2026. Linux x64 workspace, Node 24.19.0, npm 11.9.0; Functions production runtime configured for Node 22. Firebase CLI 15.32.1. Java 21 was installed locally for the Firebase data emulators. Flutter stable source 3.47.6 and its Dart 3.13.5 SDK were used for dependency resolution/static analysis. Native Android SDK/device tooling was not available.

## Completed checks

| Check | Result | Evidence |
|---|---|---|
| Functions TypeScript build | PASS | `npm --prefix functions run build` |
| React TypeScript and Vite production build | PASS | `npm --prefix customer_web run build` |
| Domain/schema tests | 22 PASS | `functions/test/domain.test.ts` |
| Firebase integration | 36 PASS | `scripts/integration.mjs`, `emulator-results.json` |
| Flutter dependency resolution | PASS, lockfile generated | Offline Dart pub resolver, genuine downloaded Pub packages and exact-tag Flutter SDK |
| Flutter/Dart static analysis | PASS, no issues | Dart analyzer across app and test sources using resolved dependencies |
| Customer browser acceptance | 8 PASS | `ui-results.json`; Chromium 153, 1440px and 360px viewports |
| Customer final receipt | Rendered to A4 PDF and visually inspected, 1 page | `sample-final-receipt.pdf` |

The integration run used actual Firebase Auth, Firestore and Storage emulators, plus the **exact exported API function handler** served over a local TCP test harness. The standard Functions emulator initialized but could not serve requests because this environment prohibits its Unix-domain socket. This is not a full Functions-runtime deployment test. No fake success handlers or alternative persistence were substituted.

Integration coverage includes registration/login/reset request, UID-bound onboarding, own-shop and cross-shop API/Firestore access, private Storage/photo boundaries, incomplete uploads, concurrent intake retry, Case C without phone, family allowlist and API-level approval denial, invalid/revoked/expired links, quote approval/revision gates, wrong/tracking-token collection-proof denial, final settlement retry, real-payment totals, saved terms, immediate deletion lockout, retry-safe deletion scheduling and emulator cleanup of the shop subtree/Auth account.

Last locally measured customer `/track` refresh: **39 ms** after an issued valid link, warm local TCP handler + Firestore emulator, fictitious small dataset. This is not an Android/mobile-network or production SLA measurement. The two-minute human intake goal has not been timed.

## Environment blocks and safer alternatives

- Initial Flutter tool bootstrap was stopped by automatic approval review because it attempted access to an instance metadata service. That request was not approved or bypassed.
- Static checks instead used the downloaded Dart SDK, exact Git-tag Flutter sources and public Pub archives. Dependency resolution ran with `--offline`, without requesting instance metadata. `pubspec.lock` is a real solver result, not a hand-written approximation.
- Full Flutter CLI build/widget execution and native Android packaging remain unverified. No APK or AAB is included or claimed.
- Firebase data emulators ran successfully. Functions emulator Unix sockets were blocked; the isolated TCP test harness executed the same exported handler for integration tests.
- The browser suite completed using a locally extracted Chromium 153 executable. Results are recorded in `ui-results.json`. Screenshots in `screenshots/` are actual local renders, not mockups.

## Still required before release

1. Run the provided Flutter widget tests and an Android debug build on the owner's Windows/Android setup.
2. Test a physical Android phone: camera denial/recovery, photo interruptions, small screens/keyboard, dialer/share, QR scan and PDF print/share. Browser receipt rendering is not a substitute for Flutter PDF/native-plugin testing.
3. Test actual password-reset completion and sign-out/account switching in Flutter, and recent reauthentication/account-deletion UI.
4. Exercise scheduled cleanup after seven days and partial failure on the real project; verify real IAM, CORS, HTTPS URLs, Storage access and Firebase quotas.
5. Validate large-record search cost/latency, long quote/PDF page wrapping and real shop-intake timing. Full-shop search is deliberately capped and needs a scale review.
6. Build and inspect an owner-signed production AAB, target-API/native-library compatibility, Play pre-launch reports and applicable closed testing.

The local evidence supports the tested workflow/security behaviour; it does not establish production readiness, guaranteed security, Play approval or cloud deployment.

## Browser checks and print verification

`npm run test:ui` runs the customer website against seeded emulator records through the same handler. Install a browser first with `npx playwright install chromium`. An existing local Chromium executable can be selected with `RP_CHROMIUM`. The suite verifies real quote display, private-token address-bar clearing, a 360px layout, explicit approval confirmation, backend decision save, same-tab customer-to-family access switching, family financial/control exclusion, receipt PDF output and generic invalid-link state. Eight grouped assertions passed; no browser page errors were recorded. The final A4 receipt was rendered with print margins and inspected.
