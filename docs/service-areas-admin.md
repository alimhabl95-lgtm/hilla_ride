# Dynamic Iraq Service Area Management

Hierarchy: **Province → District → Subdistrict** (Country = Iraq container).

Administrators manage all levels from Admin → **Service areas**. Driver and customer apps sync active areas from Firestore — **no app store update** when you add Baghdad, Najaf, or more Babil subdistricts.

## First-time setup

1. Open https://hello-tiktok-57dc5-admin.web.app  
2. Go to **Service areas**  
3. Click **Seed Babil defaults** (Iraq → Babil → districts / subdistricts)  
4. Edit names, radii, customer visibility, services, commission, pricing, hours  
5. Use ⋮ menu: **Activate / deactivate**, **Archive**, or **Delete** (soft-archive)

## Status lifecycle

| Status | New ride requests | History |
|--------|-------------------|---------|
| `active` | Allowed (if open + ride service) | Kept |
| `inactive` | Blocked immediately | Kept |
| `maintenance` | Blocked | Kept |
| `archived` | Blocked | Kept |

Deactivate / archive / delete **cascades** to children (province → districts → subdistricts). Documents are never hard-deleted.

## Per subdistrict settings

- Center lat/lng + search radius (km)  
- Services: `ride`, `food`, `grocery`, `pharmacy`, `courier`  
- Commission: global or area-specific %  
- Pricing: global brackets **or** area base / per-km / minimum  
- Operating hours: always-open or scheduled (closed hours reject new requests)

## App sync

- Flutter: `ServiceAreaService.startCatalogSync()` → `ServiceAreaCatalog`  
- iOS: `ServiceAreaCatalog.shared.start()` at bootstrap  
- After the first snapshot, seed/hardcoded areas are **not** used — empty active set means no new rides  

## Collections

`serviceCountries` · `serviceProvinces` · `serviceDistricts` · `serviceSubDistricts`

## Callables

- `saveServiceArea`  
- `setServiceAreaStatus` (optional cascade)  
- `deleteServiceArea` (soft → archived + cascade)  
- `seedServiceAreas`
