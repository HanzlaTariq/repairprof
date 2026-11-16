# Architecture and data flow

## Connected components

The Flutter owner app signs in with Firebase Authentication. It sends a current Firebase ID token in the Authorization header to the HTTPS API. The API derives the shop path from the verified UID; clients never choose an owner ID. Firebase Admin SDK handles Firestore transactions and private Storage objects.

The React customer page has no shop account or unrestricted Firestore query. A server-generated 256-bit token arrives in a URL fragment (`/#t=...`). The page immediately clears the fragment and retains the token only in memory. POST bodies carry the token to `/track` and `/decision`; the API checks its SHA-256 lookup, scope, expiry, current ticket epoch and shop status on every request. There are no analytics, external QR endpoints, third-party fonts or public photo URLs.

Customer refresh is manual and every 30 seconds while visible. A hidden page makes no periodic request. Returning to a visible page refreshes. A hard reload after the fragment is removed requires reopening the original private link. Switching to another fragment link in the same tab clears the old projection and ignores stale in-flight responses. Sharing a screenshot or original link still exposes access; this is bearer access, not independent identity verification.

## Main records

| Path | Contents | Client access |
|---|---|---|
| `shops/{uid}` | Saved shop profile/defaults | Same authenticated owner reads; API writes |
| `shops/{uid}/tickets/{id}` | Intake/contact/device, shop terms snapshot, quotes/decisions, timeline, contact attempts, settlements/final warranty | Same owner reads; API writes |
| `.../tickets/{id}/secrets/collection` | Collection-code verifier, failed attempts, lock expiry | Server only |
| `shops/{uid}/commands/{requestId}` | Mutation fingerprint and non-secret result | Server only |
| `shops/{uid}/uploads/{requestId_slot}` | Sanitized private object path, input hash, consumed/cleanup flags | Server only |
| `shops/{uid}/meta/counter` | Transactional display-number sequence | Server only |
| `access/{sha256(token)}` | UID/ticket/scope/epoch/expiry; no raw token | Server only |
| `rateLimits/{sha256(key)}` | Rolling minute bucket; 24-hour expiry | Server only |
| `deletionRequests/{uid}` | Account cleanup scheduling | Server only |
| Storage `shops/{uid}/intakes/{requestId}/{slot}.jpg` | Resized JPEG with metadata removed | Authenticated owner API only |

The first display number per shop is RP-1001. Internal IDs combine the owner and stable intake request identifier through SHA-256. Display numbers are not credentials and may repeat across different shops.

## Lifecycle

Received → Checking. A quote creates Awaiting Approval. Explicit approval of the latest quote permits the owner's start action to enter Repairing. Extra work creates another quote and returns to Awaiting Approval. Completed and checked work enters Ready for Pickup. Declined quotations or unrepairable devices enter Ready for Return. Both ready states require verified physical handover to enter Delivered. Delivered is terminal; later balance payments update settlement history without reopening the device.

Quotes and decisions remain versioned. Money is integer paisa/minor units. The API recomputes quotation totals from item quantity and price. Unrepaired returns use only the intake's previously agreed inspection/return charge. They receive no new repair warranty.

## Transaction boundaries

Critical mutations read the shop, idempotency key and ticket in a Firestore transaction, validate prerequisites, then commit the ticket, event and command result together. Same request/body retries return the same non-secret result; changed bodies with the same request ID fail. Counters and intake records are committed together.

Photos are uploaded before intake confirmation. The server checks a JPEG/PNG, limits decoded pixels, rotates/resizes it, removes metadata and saves a private JPEG. Stable image slots compare input hashes so interrupted uploads can be retried. Intake commits only after every selected slot has a confirmed upload record. Abandoned uploads are cleaned after 24 hours by daily maintenance.

Secrets are never recoverable from command replay. If a successful intake/access/reissue response is lost, the record is still confirmed without duplicating it. The UI explains that a new collection code/link must be reissued, which replaces the old credential and records an audit event.

## Search and summaries

For this small-shop MVP, the backend scans the complete own-shop collection (maximum 10,000 records) before applying case-insensitive substring search over ticket number, customer name and device model, status, delivered/open and intake-date filters. It then returns pages of 25. It does not search only the currently loaded page. Intake enforces the cap. This strategy has linear read cost and is not appropriate for a large public deployment without measured indexing/search work.

Open and ready counts use the intake date range; delivered count uses collection date; received-money totals use payment-event dates. All are calculated from persisted records. No quoted amount is counted as received money.

## Maintenance

`dailyMaintenance` deletes expired access records, old limiter counters, abandoned intake images and deletion-requested accounts/data. A deletion request immediately disables application access. After seven days, the next daily run removes Storage objects, access records, the shop subtree and Firebase Auth account. Partial failures are retried in the next run. This job must be deployed and monitored before public launch.
