# Play Store release: owner checklist

Checked against official sources on 4 October 2026. Console requirements can change; recheck them when uploading. Source code is supplied; no APK/AAB, upload key, production hosting or Play approval is claimed.

## Release steps

1. **Choose publisher identity and application ID.** `com.repairproof.app` is only the source default. Set a unique ID before Firebase registrations, signing and first Play upload. Do not change it after publishing an app you intend to update.
2. **Create/configure the real Firebase project.** Enable email/password Auth, Firestore, private Storage, Functions and Hosting. Read the billing section before enabling Blaze. Deploy rules/indexes and daily maintenance along with the API. Test using two real test shop accounts and customer browsers outside the development network.
3. **Finish Android verification.** Run `flutter analyze`, `flutter test`, a debug build on a physical Android phone, then a production-configured signed build. Test camera denial/interruption, upload disconnect, background/resume, sign-out/account switch, receipts/printing/sharing, no-contact intake, family privacy, stale quotes, wrong collection proof and deletion. These cannot be replaced by backend unit tests.
4. **Finalize privacy and deletion.** Publish your actual privacy policy and support contact, keep the in-app notice consistent, configure `/delete-account` with Firebase web credentials, and verify actual scheduled deletion. Do not publish the unconfigured publisher-contact notice.
5. **Create your private upload key.** In a private folder outside the project:

```powershell
keytool -genkey -v -keystore C:\Users\YOUR_USER\repairproof-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Review the identity fields yourself. Back up the key securely. Copy `android/key.properties.example` to `android/key.properties` and enter your values. The project deliberately refuses release builds without signing configuration.

6. **Build the AAB.** Create `shopkeeper_app/config/production.json` with production Firebase values and HTTPS URLs, then run `powershell -File scripts/build-release.ps1` from the repository root. It runs local checks/build only; it does not deploy or publish. Increase `version: 1.0.0+1` build number for each later upload.
7. **Play Console setup.** Complete developer identity/account verification, app classification, target audience, content rating, ads declaration (this MVP has no ad SDK), privacy-policy URL, public deletion URL, support email and accurate Data safety declarations. Declare actual collected data and processing; do not claim “no data collected” for this app. Account details, customer contact information, exterior photos, repair records and payment/receipt history are handled by the service.
8. **Store assets.** Create the final 512×512 app icon, feature graphic, phone screenshots and descriptions from the real app after verification. The included launcher vector is an application asset, not a complete store-listing package. Do not use customer information in screenshots.
9. **Test distribution.** Start with internal testing. For personal developer accounts created after 13 November 2023, the current official guidance requires at least 12 opted-in closed-test testers for 14 continuous days before applying for production access. Meet the exact eligibility shown in your own console.
10. **Submit and monitor.** Review the generated production AAB, finish pre-launch reports and address review feedback. Upload/publishing requires the owner's deliberate action. Monitor errors, maintenance failures, abuse and cloud spending after launch.

## Technical release baseline

Android source sets target SDK **36** and uses Flutter's compile SDK, with minimum SDK 24. Current Play guidance requires Android 16/API 36 for new standard Android apps and updates. Flutter source/tool metadata used here is stable 3.47.6; Android Gradle Plugin 9.1.0, Kotlin 2.4.0 and Gradle 9.3.1 values were read from that Flutter SDK's templates. Their real-device Android build is a remaining verification gate in this environment.

Flutter and Firebase native libraries must satisfy current native-code/page-size requirements. Check your exact production AAB with current Android tooling and Play Console pre-launch checks; no 16 KB compatibility result is claimed without a native build.

## Cloud costs

Firebase's official guidance states that Cloud Storage requires a Blaze billing plan; Cloud Functions production deployment also requires an appropriate billing-enabled project. Free usage allowances may exist, but an enabled billing account is not a guarantee of zero cost. This app performs full-shop scans for MVP search/dashboard, which adds reads. Set budgets, monitor usage and review billing before public traffic. No billing account was enabled in this work.

## Official sources

- Target SDK policy: https://support.google.com/googleplay/android-developer/answer/11926878
- Testing requirements: https://support.google.com/googleplay/android-developer/answer/14151465
- Account-deletion requirements: https://support.google.com/googleplay/android-developer/answer/13327111
- Firebase Functions runtimes and management: https://firebase.google.com/docs/functions/manage-functions
- Storage billing requirements: https://firebase.google.com/docs/storage/faqs-storage-changes-announced-sept-2024
- Flutter Android release guide: https://docs.flutter.dev/deployment/android
- Android page-size guidance: https://developer.android.com/guide/practices/page-sizes

## Suggested listing text — edit after testing

**Name:** RepairProof

**Short description:** Repair tickets, customer approvals, handover receipts and shop warranties.

**Description:** Keep a clear record of every device repair. RepairProof helps shop owners record device condition and accessories, issue itemized quotations, obtain customer decisions, track repair progress and verify collection. Customers can follow a private browser link without installing an app. Permitted family contacts receive limited status information. For customers without another reachable phone, use a printable receipt and agreed check-in time. Record actual payments and the repair shop's stated warranty terms. RepairProof does not process online payments, track device location or guarantee a shop's repair warranty.
