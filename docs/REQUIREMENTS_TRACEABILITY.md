# FR-01–FR-36 traceability

All 36 requirements are represented in source. “Implemented” is not synonymous with Android device acceptance or deployment. Test boundaries are in `TEST_RESULTS.md`. D = domain/schema test suite; E = real Auth/Firestore/Storage emulators with exact API handler; U = browser acceptance script; M = manual/device check still required where not recorded as passed.

| FR | Priority | Implementation | Verification |
|---|---|---|---|
| FR-01 | Must | `auth_page.dart`, `session.dart`; Firebase Auth registration/login; `onboard` transaction binds UID | E registration/sign-in; M Android |
| FR-02 | Must | Auth reset flow; Session sign-out clears profile, pending requests and clipboard | E reset request/unauthenticated denial; M actual reset action/account switching |
| FR-03 | Must | `index.ts` ID-token verification; UID paths; Firestore/Storage rules | E cross-shop API read/write, Firestore read and private image denial |
| FR-04 | Must | Four-step `intake.dart`; `createTicket` schema/service | D schema constraints; E intake |
| FR-05 | Must | Device/condition/accessories, image picker, sanitized private `upload` and `photo` endpoints | E sanitized JPEG/read isolation/interrupted-upload prevention; M camera lifecycle |
| FR-06 | Must | A/B/C contact selector and discriminating validation | D Case C; E no-phone save |
| FR-07 | Must | B recipient/number/purpose/permission, server permission timestamp | D/E missing permission rejected |
| FR-08 | Must | Estimate/check-in/prior-charge/acknowledgement review; saved receipt | E intake; M two-minute usability target |
| FR-09 | Must | Transactional Received state, server handover time, stable request UUID and uploads | E concurrent duplicate save and incomplete-upload denial |
| FR-10 | Must | Transactional per-shop number sequence, internal hash ID | E same-ID duplicate prevention; D credential independence |
| FR-11 | Must | Server random scoped link, in-app local `QrImageView` | E token issuance; M QR scanning on phone |
| FR-12 | Must | Customer allowlist projection and React page | D projection; E scoped response; U customer page |
| FR-13 | Must | Separate family scope, status-only projection | D/E no sensitive fields; U family controls absent |
| FR-14 | Must | Token verifier, expiry, epochs, generic failures and transaction-based limiter | E unknown/expired/revoked denial; D random secrets |
| FR-15 | Must | Case A Share/Copy and `tel:` external launcher | E customer access; M share/dialer on Android |
| FR-16 | Must | Case B separate minimal link and permitted recipient display | D/E family boundaries; M manual recipient selection |
| FR-17 | Must | Case C printable handover code/estimate/shop/check-in receipt | E no-phone confirmed intake; Flutter PDF M |
| FR-18 | Must | Actual-outcome form, server recipient/time/channel/account | D no remote logging for C; M communication UI |
| FR-19 | Must | `quote_page.dart`; line-item validated totals and append-only versions | D/E quotation/revision rules |
| FR-20 | Must | Quote enters Awaiting Approval; web/phone/in-person channels | D/E pending path; U browser review |
| FR-21 | Must | Exact version/decision/time/channel/verification; immutable previous decisions | D/E stale and duplicate decisions; U explicit confirmation |
| FR-22 | Must | Backend gates Repairing on current approved quote | D/E unapproved/revised-work checks |
| FR-23 | Must | No-response remains awaiting; no auto approval on open | D no-response test; E explicit POST decision |
| FR-24 | Must | Seven `statuses` constants, no Cancelled state | D exact seven-status set |
| FR-25 | Must | `mutate()` transition allowlist, owner-only commands | D exhaustive disallowed direct transitions; E auth gates |
| FR-26 | Must | Atomic event previous/new state, server time/account/note | E single handover audit under retry; D events |
| FR-27 | Must | Completion/checking prerequisites before pickup | D/E unfinished checking rejected |
| FR-28 | Must | Decline/failure → Ready for Return, separate handover → Delivered | D decline/unrepairable/terminal paths; seed return examples |
| FR-29 | Must | Collection wizard, distinct verifier, failed-attempt lockout and documented manual resolution | E wrong proof/tracking-token release denial; M physical verification |
| FR-30 | Must | Final itemized receipt, settlement history and outstanding balance; no payment gateway | D balance; E idempotent final settlement; Flutter PDF M |
| FR-31 | Must | Saved warranty terms/date/covered work/exclusions; no new warranty for unrepaired returns | D repaired/unrepaired terms; E snapshot unchanged |
| FR-32 | Should — implement | Customer receipt/warranty period indicator uses Pakistan date | D customer projection; U customer receipt; M date-boundary acceptance |
| FR-33 | Must | Dashboard status grouping, open Tickets and separate Delivered History | E dashboard/list data; M Flutter navigation |
| FR-34 | Should — implement | Whole-shop substring search before 25-item pagination, 10,000 enforced record cap | Service implementation; M volume/search acceptance |
| FR-35 | Should — implement | Persisted-record dashboard; quotations excluded from received money | D quotation/payment distinction; E actual money totals |
| FR-36 | Should — implement | Editable shop profile/default terms; intake stores snapshot | E shop update preserves old terms; M shop form |

Additional public-release support: account deletion request in app and browser, scheduled data purge, production configuration examples and signing guard. Account lockout and the cleanup handler were tested against emulators; scheduled production execution and Play release still require owner acceptance.
