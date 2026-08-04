# Hello Tuk-Tuk Business — Web Portal & Future Mobile App

## Goal

Launch with a **Web Portal** today. Later ship **Hello Tuk-Tuk Business** on Google Play / App Store using the **same Firebase backend, Auth accounts, Firestore collections, and Cloud Functions** — no data migration for partners.

## Architecture principle

```text
┌─────────────────────┐   ┌──────────────────────────┐   ┌─────────────────────┐
│ Admin Web           │   │ Business Web Portal      │   │ Customer / Driver   │
│ (main_admin.dart)   │   │ (main_business.dart)     │   │ Mobile apps         │
└─────────┬───────────┘   └────────────┬─────────────┘   └──────────┬──────────┘
          │                            │                            │
          │         same Cloud Functions + Firestore + Auth         │
          └────────────────────────────┼────────────────────────────┘
                                       │
                    ┌──────────────────┴──────────────────┐
                    │  Future: Hello Tuk-Tuk Business App │
                    │  same main_business.dart +          │
                    │  BusinessService (no backend rewrite)│
                    └─────────────────────────────────────┘
```

- **Web Portal** = one client of the backend  
- **Future Business App** = another client of the **same** backend  
- **No business write rules live only in UI** — mutations go through `BusinessService` → HTTPS callables in `functions/business.js`

## Phase 1 (current) — Web Portal

| Capability | How |
|------------|-----|
| Login | Firebase Auth email/password (`role: businessOwner`) |
| Profile | `saveBusinessProfile` |
| Temporary close/open | `temporarilyClosed` via `saveBusinessProfile` |
| Categories / products / prices / images | `saveBusinessCategory`, `saveBusinessProduct`, Storage under `businesses/{id}/` |
| Orders accept → ready | `updateBusinessOrderStatus` |
| Dashboard stats | Live `businessOrders` + business doc streams |
| Hosting | https://hello-tiktok-57dc5-business.web.app |

Admin creates the owner account; partner never self-registers.

## Phase 2 (future) — Mobile app

Partners download **Hello Tuk-Tuk Business** and log in with the **same email/password**.

| Feature | Backend readiness |
|---------|-------------------|
| Login | Ready (same Auth) |
| Dashboard / orders / products / categories / profile / hours | Ready (`BusinessService`) |
| Temporary close | Ready (`temporarilyClosed`) |
| Push notifications | Add FCM token on `users/{uid}` + Cloud Function trigger on new `businessOrders` (no schema migration) |
| Promotions | Extend product `discountPercent` or add `promotions` subcollection + callable |
| Revenue reports | Same order streams; optional aggregate callable later |
| Branch / multi-staff | Future collections (`branches`, `businessStaff`) + callables — not required for launch |

### Packaging the mobile app

1. Reuse entry: `lib/main_business.dart` (`AppVariant.business`)  
2. New Android `applicationId` / iOS bundle id (e.g. `com.hillaride.hilla_ride.business`)  
3. Same Firebase project + Auth  
4. Enable phone/email Auth as today  
5. Wire FCM for order alerts  

No Firestore migration. Existing partners keep their catalog and history.

## Shared API surface (stable)

### Collections

- `users/{uid}` — `role: businessOwner`, `businessId`  
- `businesses/{id}` — profile, status, hours, commission, `temporarilyClosed`  
- `businesses/{id}/categories/{id}`  
- `businesses/{id}/products/{id}`  
- `businessOrders/{id}`  
- `config/businessTypes`  

### Callables (`functions/business.js`)

| Callable | Who |
|----------|-----|
| `createBusinessPartner` / `setBusinessStatus` / … | Admin |
| `saveBusinessProfile` | Owner (+ admin fields) |
| `submitBusinessForReview` | Owner |
| `saveBusinessCategory` / `deleteBusinessCategory` | Owner |
| `saveBusinessProduct` / `deleteBusinessProduct` / `duplicateBusinessProduct` / `bulkUpdateBusinessPrices` | Owner |
| `placeBusinessOrder` | Customer |
| `updateBusinessOrderStatus` | Owner / driver / admin |

### Client module

`lib/core/services/business_service.dart` — **single** Dart API used by:

- Business Web Portal  
- Future Business mobile app  
- Customer Stores / Driver delivery  
- Admin Business Partners panel  

## Rules for new features

1. Put validation and side effects in **Cloud Functions**, not only in Flutter widgets.  
2. Prefer new callables / fields on existing docs over one-off web-only logic.  
3. Keep `BusinessService` as the only write path from apps.  
4. UI may differ (web rail vs mobile bottom nav) — **data contract must not**.

## Seamless transition checklist

- [x] Shared Auth + `businessOwner` role  
- [x] Shared Firestore schema  
- [x] Shared callables + `BusinessService`  
- [x] Portal UI responsive for phone-width (Phase 2 shell)  
- [x] Temporary close without status change  
- [ ] Business-order FCM pushes (Phase 2)  
- [ ] Dedicated Play/App Store packaging (Phase 2)  
- [ ] Branches / staff accounts (later)  
