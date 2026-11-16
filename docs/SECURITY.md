# Security and privacy design

Every owner API command verifies a current Firebase ID token and derives its own shop UID. Strict schemas reject injected owner IDs, totals, statuses and unknown keys. Firestore denies direct writes; sensitive subcollections have no client read permission. Storage denies all client reads/writes, so sanitized condition images are returned only through authenticated own-ticket endpoints.

Tracking tokens are 256 random bits; only SHA-256 verifiers are stored. Collection credentials are separate, high-entropy codes with independent verifiers. Tokens never appear in HTTP request paths, analytics or QR services. React uses no persistent token storage. Private API responses use `Cache-Control: private, no-store`, `Pragma: no-cache`, `Referrer-Policy: no-referrer` and `nosniff`. Hosting adds CSP and anti-framing headers. An owner can revoke/reissue either scope. The backend always returns a scope-specific allowlist, not hidden CSS fields.

Rate limits: 180 requests/IP/minute, 120/owner/minute, 60 valid-format tracking requests/token/minute, 10 decisions/token/minute. Collection additionally locks for 15 minutes after each fifth failed code match and records failures. CORS is not authorization. IP bucket correctness should be checked behind the exact production proxy; the application uses the runtime request IP, not a caller-supplied forwarded value. Account creation/password endpoints use Firebase Auth controls and require deployment monitoring.

Code does not log bodies, access credentials, collection secrets, customer names or photos. Unexpected errors log the error class only. Emulator Auth may print dummy password-reset URLs: keep emulator logs local and never run demo seeds in production.

## Retention and deletion

Active shop records persist until account deletion in this MVP. Expired links and limiter buckets are cleaned by daily maintenance; abandoned photo uploads after 24 hours. Deletion is requested after recent password reauthentication via the app or authenticated website page. Immediate shop lockout prevents API/Firestore access; the scheduled job erases associated Storage, access records, shop subtree and Auth account after seven days, normally by day eight. Separately exported receipts, external backups and operational cloud logs are not automatically erased by the app. Publish a deployment-specific policy that explains those honestly.

## Remaining deployment work

This is not a claim of comprehensive security. Before public rollout: test the real Firebase project/IAM boundaries; review Auth abuse quotas, HTTPS origins, Cloud Function invocation policy, Storage lifecycle/backups and monitoring; monitor maintenance failures; perform an independent security review and load testing. Consider App Check on owner traffic after device enrollment/testing; App Check is not configured or claimed here. No production secrets are in the package.

## Credential configuration

`FIREBASE_API_KEY`, app ID, sender ID and project ID are public client identifiers. They do not grant Admin SDK access. Admin credentials must stay on managed Functions/server environments; never embed service-account JSON in Flutter or React. Upload signing keys and passwords belong to the owner and must stay outside the ZIP and Git. No signing key is supplied.

## Reporting

Set a real publisher support address in `VITE_SUPPORT_EMAIL` and the Play listing before release. The source package does not invent a support contact.
