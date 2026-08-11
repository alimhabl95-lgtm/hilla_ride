/**
 * Shared polygon geometry helpers so iOS, Android/Flutter, and Cloud
 * Functions treat the same stored (or synthesized) boundary identically.
 */
const EARTH_RADIUS_KM = 6371.0;

function deg2rad(deg) {
  return (deg * Math.PI) / 180;
}

function rad2deg(rad) {
  return (rad * 180) / Math.PI;
}

function distanceKm(a, b) {
  const dLat = deg2rad(b.lat - a.lat);
  const dLng = deg2rad(b.lng - a.lng);
  const lat1 = deg2rad(a.lat);
  const lat2 = deg2rad(b.lat);
  const sinDLat = Math.sin(dLat / 2);
  const sinDLng = Math.sin(dLng / 2);
  const h =
    sinDLat * sinDLat + Math.cos(lat1) * Math.cos(lat2) * sinDLng * sinDLng;
  return EARTH_RADIUS_KM * 2 * Math.atan2(Math.sqrt(h), Math.sqrt(1 - h));
}

/**
 * Ray-casting point-in-polygon test. `polygon` is an open ring (first
 * point not repeated at the end), each `{lat, lng}`. Works directly on
 * lat/lng degrees, an acceptable approximation for sub-district sized areas.
 */
function pointInPolygon(point, polygon) {
  if (!Array.isArray(polygon) || polygon.length < 3) return false;
  let inside = false;
  const x = point.lng;
  const y = point.lat;
  let j = polygon.length - 1;
  for (let i = 0; i < polygon.length; i++) {
    const xi = polygon[i].lng;
    const yi = polygon[i].lat;
    const xj = polygon[j].lng;
    const yj = polygon[j].lat;
    const intersects =
      (yi > y) !== (yj > y) && x < ((xj - xi) * (y - yi)) / (yj - yi) + xi;
    if (intersects) inside = !inside;
    j = i;
  }
  return inside;
}

function destinationPoint(start, distanceKmValue, bearingDeg) {
  const d = distanceKmValue / EARTH_RADIUS_KM;
  const brng = deg2rad(bearingDeg);
  const lat1 = deg2rad(start.lat);
  const lon1 = deg2rad(start.lng);

  const lat2 = Math.asin(
    Math.sin(lat1) * Math.cos(d) + Math.cos(lat1) * Math.sin(d) * Math.cos(brng),
  );
  const lon2 =
    lon1 +
    Math.atan2(
      Math.sin(brng) * Math.sin(d) * Math.cos(lat1),
      Math.cos(d) - Math.sin(lat1) * Math.sin(lat2),
    );
  return { lat: rad2deg(lat2), lng: rad2deg(lon2) };
}

/**
 * Builds a regular `sides`-gon polygon approximating a circle of
 * `radiusKm` centered at `center`. Used as a temporary boundary for
 * sub-districts that don't yet have an Admin-drawn polygon.
 */
function syntheticPolygonFromCircle(center, radiusKm, sides = 16) {
  const points = [];
  for (let i = 0; i < sides; i++) {
    const bearingDeg = (360 / sides) * i;
    points.push(destinationPoint(center, radiusKm, bearingDeg));
  }
  return points;
}

/**
 * Maximum distance (km) from `center` to any vertex of `polygon`.
 */
function boundingRadiusKm(center, polygon) {
  if (!Array.isArray(polygon) || polygon.length === 0) return 0;
  let maxKm = 0;
  for (const p of polygon) {
    const km = distanceKm(center, p);
    if (km > maxKm) maxKm = km;
  }
  return maxKm;
}

/**
 * Resolves the effective boundary for an area: the stored polygon when
 * present (>= 3 points), otherwise a synthesized polygon from center +
 * radius. Mirrors the same resolution used on iOS/Android so the backend
 * enforces exactly what the client already filtered by.
 */
function effectiveBoundary(center, radiusKm, storedBoundary) {
  if (Array.isArray(storedBoundary) && storedBoundary.length >= 3) {
    return storedBoundary;
  }
  return syntheticPolygonFromCircle(center, radiusKm);
}

/**
 * True when `point` ({lat, lng}) falls inside the effective boundary of
 * an area described by `center` + `radiusKm` (+ optional stored `boundary`).
 */
function isWithinBoundary(point, center, radiusKm, storedBoundary) {
  const boundary = effectiveBoundary(center, radiusKm, storedBoundary);
  return pointInPolygon(point, boundary);
}

/**
 * True when `point` belongs to this area specifically, resolving the
 * ambiguity that arises when two *temporary* circle boundaries (no
 * Admin-drawn polygon yet) overlap — e.g. Qasim and Al-Shumali are both
 * large synthesized circles inside the same district. In that overlap case
 * the point is assigned to whichever area's center is nearest, so a point
 * clearly inside Qasim never also counts as "inside" Al-Shumali just
 * because the circles overlap. An Admin-drawn polygon (on this area or a
 * neighboring one) is always authoritative and skips the tie-break
 * entirely. `others` is a list of `{ center, radiusKm, boundary }`.
 */
function isWithinBoundaryUnique(point, center, radiusKm, storedBoundary, others = []) {
  if (!isWithinBoundary(point, center, radiusKm, storedBoundary)) return false;
  if (Array.isArray(storedBoundary) && storedBoundary.length >= 3) return true;

  const selfDistanceKm = distanceKm(center, point);
  for (const other of others) {
    if (Array.isArray(other.boundary) && other.boundary.length >= 3) {
      if (pointInPolygon(point, other.boundary)) return false;
      continue;
    }
    if (!isWithinBoundary(point, other.center, other.radiusKm, undefined)) continue;
    if (distanceKm(other.center, point) < selfDistanceKm) return false;
  }
  return true;
}

module.exports = {
  pointInPolygon,
  syntheticPolygonFromCircle,
  boundingRadiusKm,
  effectiveBoundary,
  isWithinBoundary,
  isWithinBoundaryUnique,
  distanceKm,
};
