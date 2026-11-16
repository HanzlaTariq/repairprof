# RepairProof — Windows / VS Code guide

## 1. ZIP extract aur tools

ZIP ko `D:\RepairProof` mein extract karein. Andar wala `repairproof` folder VS Code mein **File → Open Folder** se kholein. Terminal mein project root par `firebase.json` aur `package.json` nazar aane chahiye.

Install/check:

- Flutter stable **3.47.6** (Dart is ke sath aata hai). `flutter --version` aur `flutter doctor -v` chalayen.
- Android Studio: SDK Platform 36, SDK Platform Tools, Command-line Tools aur Android Emulator install karein. Flutter agar koi specific SDK/NDK mange to SDK Manager se woh install karein.
- Node.js **22**. `node --version` / `npm --version`.
- Java **21**: Firebase CLI ko Java 21 chahiye. `java -version`. Android Gradle ki source compatibility Java 17 hai, Java 21 se bhi Gradle chal sakta hai.
- VS Code mein Flutter aur Dart extensions.
- `flutter doctor --android-licenses` chala kar Android license terms khud review karein.

Flutter SDK ka path aur Java ka path Windows Environment Variables mein add karein; phir naya terminal kholein. JDK select karne ke liye zarurat ho to `flutter config --jdk-dir="C:\path\to\jdk-21"`.

## 2. Local backend start — Firebase account zaroori nahi

Project root ke terminal mein:

```powershell
npm ci
npm --prefix functions ci
npm --prefix customer_web ci
npm run build
npm run emulators
```

Terminal khula rehne dein. Emulator UI: `http://127.0.0.1:4000`. Customer website: `http://127.0.0.1:5000`. Auth 9099, Firestore 8080, Storage 9199 aur Functions 5001 ports use karte hain. Do emulator commands ek hi waqt na chalayen.

## 3. Demo records

Doosra VS Code terminal kholein. Project root par:

```powershell
npm run seed
```

Demo login: `demo@repairproof.test` / `DemoRepair#2026`. Seed 8 fictitious records banata hai: personal contact, permitted family, no contact, pending/revised quote, pickup, return, repaired delivery aur unrepaired delivery. `03000000000` sirf dummy number hai; dial/share na karein.

## 4. Pehle Chrome par app chalayen

Doosray terminal mein:

```powershell
cd shopkeeper_app
flutter pub get
flutter run -d chrome --web-port 5200 --dart-define-from-file=config/emulator.web.json
```

Shopkeeper app Chrome par khulegi. Customer website alag hai (`http://127.0.0.1:5000`), wahan shop login screen nahi honi chahiye. Shop app mein demo login karein ya naya account register karke Shop setup complete karein.

## 5. Android emulator par

Android Studio → Device Manager → ek Android Virtual Device start karein. Project root se:

```powershell
cd shopkeeper_app
flutter devices
flutter run --dart-define-from-file=config/emulator.android.json
```

Android emulator laptop ko `10.0.2.2` se access karta hai. `127.0.0.1` Android emulator ke andar usi emulator ko kehta hai. Is liye Android aur Chrome ke configs alag hain.

Agar customer link Android emulator ke browser mein kholna hai, tracking base `http://10.0.2.2:5000` set karein; laptop browser ke liye `http://127.0.0.1:5000` rakhein. Ek hi link dono addresses ka kaam nahi karta.

## 6. Real Android phone par local test

USB debugging on karein; `flutter devices` mein phone select karein. `adb reverse tcp:9099 tcp:9099` aur `adb reverse tcp:5001 tcp:5001` se USB par backend forward kiya ja sakta hai. Is surat mein phone config ka `EMULATOR_HOST` `127.0.0.1` rakhein. Customer Hosting ke liye `adb reverse tcp:5000 tcp:5000` bhi chalayen.

Private Wi-Fi LAN alternative: emulator hosts ko temporary local LAN address/`0.0.0.0` par bind karein, Firebase `WEB_ORIGINS` mein exact local origin add karein, phone config mein laptop ka private IP dein, Windows firewall ko sirf private trusted network tak limit karein. `TRACKING_BASE` bhi laptop ka wahi IP ho. **Emulators ko internet, public tunnel ya router port-forward par expose na karein; in mein production access protections nahi hotin.** Local loopback default intentionally laptop-only hai.

## 7. Workflow practice

1. New repair → Case A/B/C select karein → device/condition/accessories → estimate/check-in → acknowledgement → Save.
2. Save confirmed hone par record khulega. **Print handover receipt** se PDF kholein. Collection code alag aur private hai.
3. Start checking → quotation items add karein → issue quote. State Awaiting Approval hogi.
4. Customer link issue karein; link customer browser mein open karein. Family link se approve nahi ho sakta.
5. Customer approval ke baad shopkeeper **Start / resume approved repair** karega. Website khulne se automatic approval nahi hoti.
6. Completed/checking note → Ready for Pickup → collector/proof verify → payment/warranty record → actual handover confirm.
7. Final receipt print karein. Case C mein online approval nahi chahiye: customer ke in-person decision ko record karein.

Share button sirf share sheet kholta hai. Dialer sirf call screen kholta hai. Actual result **Log contact outcome** mein khud record karein. Case B ke family recipient ko pricing ya collection code na dein.

## 8. Tests aur debug APK

Project root:

```powershell
npm test
npm run test:emulator
powershell -File scripts/check-android.ps1
```

Test command chalate waqt pehle se running emulators band karein. Agar host Functions emulator Unix sockets support nahi karta, `npm run test:handler` same HTTP handler ko TCP par chalata hai; data phir bhi real emulators mein hota hai.

Debug APK ka output `shopkeeper_app/build/app/outputs/flutter-apk/app-debug.apk` hoga **jab build aapke PC par successfully complete ho**. Yeh local-emulator APK hai, public customers ke liye nahi.

## 9. Production Firebase setup — owner ke account par

Cloud deployment billable ho sakti hai: Functions aur Storage ke liye Blaze plan required hai. Budget alerts charges ka hard cap nahi hote. Account/billing/deploy ka faisla aap khud karein; is ZIP ne koi cloud project deploy nahi kiya.

1. Firebase Console mein project create/select karein. Email/Password Authentication enable karein.
2. Firestore database aur Cloud Storage bucket banayen. Region/location ka faisla data privacy aur latency ko dekh kar karein. Functions is code mein `us-central1` hain.
3. Android app register karein: current package `com.repairproof.app`. Play par unique package choose karna ho to `android/app/build.gradle.kts`, Kotlin namespace/path aur Firebase registration ko ek sath update karein.
4. Firebase CLI sign in: `npx firebase login` (project root). `.firebaserc.example` se `.firebaserc` banakar actual project ID fill karein.
5. FlutterFire optional setup: `dart pub global activate flutterfire_cli`, phir `shopkeeper_app` folder mein `flutterfire configure --project=YOUR_PROJECT --platforms=android,web`. Yeh Firebase app registrations/config generate karta hai. App runtime is build mein **explicit dart-define configuration** use karta hai; generated `firebase_options.dart` ko automatic use nahi karta. Firebase Console/FlutterFire output se exact public values neeche JSON mein copy karein.
6. `shopkeeper_app/config/production.example.json` ki copy `production.json` banayen. Actual public Firebase app identifiers, Functions HTTPS URL aur Hosting URL fill karein. Android Firebase app ID use karein; web shop build ke liye separate web app ID wali file banayen.
7. `functions/.env.example` se `functions/.env.YOUR_PROJECT` banayen. Actual Storage bucket aur exact website origins likhein. `.env.local` sirf emulator ke liye hai.
8. `customer_web/.env.example` se `.env.production` banayen. Public Firebase web values, actual support email aur `VITE_EMULATORS=false` set karein. API base `/api` Hosting rewrite use karega.
9. Privacy page ko apne publisher/contact, data retention, deployed providers aur actual practices ke mutabiq finalize karein. Account deletion ko actual project par test karein; scheduled cleanup deploy hona zaroori hai.
10. Project root par `npm run build`. Phir **sirf jab aap deploy karna chahein**:

```powershell
npx firebase deploy --only firestore:rules,firestore:indexes,storage,functions,hosting --project YOUR_PROJECT
```

Aapka successful deployed Hosting URL internet par doosray devices se chalega. Localhost link doosray shehr ke customer ke liye kaam nahi karta.

Service-account private key, key.properties, .jks aur passwords source ZIP/Git mein kabhi add na karein. Firebase apiKey/appId public client configuration hain; woh Admin service-account secrets nahi hain.

## 10. Play Store AAB

`docs/PLAY_STORE_RELEASE.md` parhein. Apni private upload key banayen, `android/key.properties.example` se private `key.properties` fill karein. Project root par:

```powershell
powershell -File scripts/build-release.ps1
```

AAB successful build ke baad `shopkeeper_app/build/app/outputs/bundle/release/app-release.aab` mein hoga. Script public upload nahi karta. Play Console internal/closed testing, privacy, Data safety, deletion URL aur store listing complete karna abhi owner ka kaam hai.
