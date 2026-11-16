# RepairProof

Digital Repair Handover, Status Tracking and Warranty Management.

A connected Flutter shopkeeper app, React customer tracking website and Firebase backend. Built from the supplied `Pasted text(8).txt`. The referenced `RepairProof_Hanzla_Tariq.pdf` was not supplied and was not read.

**Delivery status:** source implementation and local verification package. It is not a deployed service or a signed Play Store release. Read `docs/TEST_RESULTS.md` for the exact tested/unrun boundaries. No production account, billing, real message or publishing action has been performed.

## Start on Windows

Install Flutter stable **3.47.6**, Android Studio/SDK 36, Node **22**, and Java **21**. Open this `repairproof` folder in VS Code. Open `SETUP_ROMAN_URDU.md` for step-by-step instructions.

In the project root:

```powershell
npm ci
npm --prefix functions ci
npm --prefix customer_web ci
npm run build
npm run emulators
```

Keep that terminal running. In a second terminal, from the project root:

```powershell
npm run seed
cd shopkeeper_app
flutter pub get
flutter run -d chrome --web-port 5200 --dart-define-from-file=config/emulator.web.json
```

For an Android emulator instead:

```powershell
cd shopkeeper_app
flutter devices
flutter run --dart-define-from-file=config/emulator.android.json
```

Select the Android emulator when asked. Local shop login after seeding: **demo@repairproof.test / DemoRepair#2026**. These are fictitious local credentials only. Customer links are issued from the repair's **Contact & private access** section. They open the customer website at `http://127.0.0.1:5000` on the development computer. See the networking section before trying a second phone.

The shop app uses Firebase Authentication plus protected HTTP Cloud Functions; it never writes business records directly to Firestore. All three contact cases, seven statuses, exact-version quote decisions and separate collection proof are enforced by the backend.

## Commands

| From project root | Purpose |
|---|---|
| `npm run build` | Compile Functions and build customer website |
| `npm test` | Domain/schema tests |
| `npm run test:emulator` | Full Functions/Auth/Firestore/Storage emulator integration suite |
| `npm run test:handler` | Same exported HTTP handler with real data emulators over TCP; useful where Unix sockets are unavailable |
| `npm run seed` | Create 8 fictitious demo repairs; never runs against production |
| `powershell -File scripts/check-android.ps1` | Flutter checks and local debug APK |
| `powershell -File scripts/build-release.ps1` | Locally build owner-signed production AAB after configuration |

The release script never uploads. Never use emulator settings for a public release.

## Project layout

- `shopkeeper_app/`: Flutter, GetX controllers/bindings/named routes, Material 3, PDF printing, QR/manual sharing.
- `customer_web/`: React/TypeScript/Vite, scoped repair/quotation/warranty view, privacy and account-deletion pages.
- `functions/src/domain.ts`: lifecycle and quotation/collection rules.
- `functions/src/schemas.ts`: strict input validation.
- `functions/src/store.ts`: Firestore transactions, scopes, idempotency, photos, search and maintenance.
- `functions/src/index.ts`: authenticated/scoped HTTP boundary, rate controls, scheduled maintenance.
- `scripts/`: emulator seed and repeatable acceptance checks.
- `docs/`: architecture, traceability, security, evidence, release guidance.

## Before customers use it

Configure the owner's Firebase project and public HTTPS hosting, review billing, complete physical Android testing, create an upload signing key, finalize the publisher privacy/support details and meet Play Console release requirements. `docs/PLAY_STORE_RELEASE.md` explains the remaining work. This implementation is an MVP; a public launch still needs real-device testing and an independent security review.

Student documentation: **Hanzla Tariq · COSC231103001 · COSC-7B · Mobile Application Development**. These details are confined to project documentation.
