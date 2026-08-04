# Multi-Business Management System

Hello Tuk-Tuk supports restaurants, supermarkets, pharmacies, and future partner types as a **database-driven** platform. Mobile apps never hardcode businesses, menus, or prices.

## Surfaces

| Surface | Entry | URL / run |
|---------|-------|-----------|
| Admin — Business Partners | Admin tab | https://hello-tiktok-57dc5-admin.web.app |
| Business Portal (Phase 1) | `lib/main_business.dart` | https://hello-tiktok-57dc5-business.web.app |
| Future Business mobile app | Same `AppVariant.business` + `BusinessService` | See `docs/business-app-architecture.md` |
| Customer Stores tab | Android Flutter + iOS native bottom nav | Live from Firestore |
| Driver delivery offers | Android Flutter + iOS native home panel | Ready orders stream |

## Store release versions

| Platform | Version |
|----------|---------|
| Android (Play) | `1.1.0` (64) — from `pubspec.yaml` |
| iOS (App Store / TestFlight) | `2.2.0` (90) — `codemagic.yaml` + Xcode project |

## Workflow

1. Admin → **Business Partners** → **Seed types** (once)  
2. **New partner** → creates Auth user (`businessOwner`) + business (`approved`)  
3. Owner logs into Business Portal (email/password)  
4. Completes profile, categories, products  
5. **Submit for review**  
6. Admin sets status **live**  
7. Customers/drivers see the partner **immediately** (no app update)

## Statuses

`draft` · `pendingReview` · `approved` · `live` · `rejected` · `suspended` · `archived`

Only **`live`** is visible to customers.

## 5. Customer App

Tabs: **Ride | Stores**

The Stores page loads dynamically from Firestore. Only businesses with `status == live` are visible.

Customers automatically receive (real-time streams, no app update):

- New businesses  
- Categories  
- Products  
- Prices  
- Discounts (`discountPercent` on products)  
- Images  
- Ratings  

If a partner is suspended while the store screen is open, ordering is blocked immediately.

## 6. Driver App

When a business marks an order as **Ready**, drivers see it instantly under **Ready Delivery Orders**.

Driver presses **Take Delivery** → status becomes **Out For Delivery** (driver assigned).

## 7. Dynamic synchronization

Always loaded from Firestore / Cloud Functions (never hardcoded in apps):

| Data | Source |
|------|--------|
| Business types | `config/businessTypes` |
| Businesses | `businesses` |
| Categories / products | `businesses/{id}/categories`, `.../products` |
| Prices / discounts / images | product fields |
| Working hours | business `hours` |
| Commission | business `commissionPercent` |
| Service areas | service-area catalog (separate admin) |
| Orders | `businessOrders` |

Promotions today are modeled as product discounts; extend with a promotions collection later without changing app release gates.

## 8. Scalability

Architecture is modular: Admin, Business Portal, Customer, Driver are thin clients over shared Firestore + callables. Supports growing counts of businesses, types, categories, products, customers, drivers, and orders. Use pagination/limits on streams (`limit`) and composite indexes as volume grows.

## Final requirement — real-time sync

Customer App, Driver App, Business Portal, and Admin Portal synchronize via Firestore listeners and callable writes. Any approved business, category, product, price, discount, or availability change appears across the platform without application updates, restarts, or manual sync.

## Collections

- `businesses/{id}`  
- `businesses/{id}/categories/{id}`  
- `businesses/{id}/products/{id}`  
- `businessOrders/{id}`  
- `config/businessTypes`  

## Callables

`seedBusinessTypes` · `saveBusinessTypes` · `createBusinessPartner` · `setBusinessStatus` · `saveBusinessProfile` · `submitBusinessForReview` · `deleteBusiness` · `saveBusinessCategory` · `deleteBusinessCategory` · `saveBusinessProduct` · `deleteBusinessProduct` · `duplicateBusinessProduct` · `bulkUpdateBusinessPrices` · `placeBusinessOrder` · `updateBusinessOrderStatus`

## Build / deploy

```powershell
flutter build web --release -t lib/main_admin.dart -o build/web_admin
flutter build web --release -t lib/main_business.dart -o build/web_business
firebase deploy --only hosting:hello-tiktok-57dc5-admin,hosting:hello-tiktok-57dc5-business,functions,firestore
```
