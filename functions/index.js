const {onRequest} = require('firebase-functions/v2/https');
const logger = require('firebase-functions/logger');

// Overpass has no CORS support for browsers on its main instance, which is
// the reason this proxy exists at all (see StoreLocatorService on the Dart
// side). Called server-to-server there's no CORS restriction, so this can
// hit the well-provisioned main instance directly. A couple of full-planet
// mirrors are listed as fallbacks in case the main instance is briefly down
// — mirrors that turned out to hold partial data (e.g. Switzerland-only)
// during testing are deliberately not included here.
const OVERPASS_ENDPOINTS = [
  'https://overpass-api.de/api/interpreter',
  'https://overpass.kumi.systems/api/interpreter',
];

const GROCERY_SHOP_TAGS = ['supermarket', 'convenience'];
const MAX_RADIUS_METERS = 10000;

function buildQuery(lat, lon, radius) {
  const clauses = GROCERY_SHOP_TAGS.map(
    (tag) => `node["shop"="${tag}"](around:${radius},${lat},${lon});`,
  ).join('');
  return `[out:json][timeout:20];(${clauses});out body;`;
}

async function fetchFromOverpass(query) {
  let lastError;
  for (const endpoint of OVERPASS_ENDPOINTS) {
    try {
      const response = await fetch(endpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          // Overpass instances rate-limit or reject requests without a
          // descriptive User-Agent (confirmed via kumi.systems' own error
          // message asking for exactly this) — this follows the Overpass
          // API usage policy's etiquette guidance.
          'User-Agent': 'HandelisteApp/1.0 (+https://handleliste-f1659.web.app)',
        },
        body: 'data=' + encodeURIComponent(query),
        signal: AbortSignal.timeout(20000),
      });
      if (!response.ok) {
        const bodySnippet = (await response.text().catch(() => '')).slice(0, 300);
        logger.error('Overpass endpoint returned non-OK status', {
          endpoint,
          status: response.status,
          statusText: response.statusText,
          bodySnippet,
        });
        lastError = new Error(`${endpoint} responded ${response.status}`);
        continue;
      }
      return await response.json();
    } catch (err) {
      lastError = err;
      logger.error('Overpass endpoint threw', {endpoint, error: String(err), stack: err && err.stack});
    }
  }
  throw lastError ?? new Error('No Overpass endpoints configured');
}

/**
 * GET /nearbyStores?lat=..&lon=..&radius=..
 * Proxies an Overpass "grocery stores near me" query and returns the raw
 * Overpass JSON response unchanged — filtering/normalizing store names stays
 * on the Dart side (StoreLocatorService) so there's one place that logic
 * lives.
 */
exports.nearbyStores = onRequest(
  {region: 'europe-west1', cors: true, timeoutSeconds: 30, memory: '256MiB'},
  async (req, res) => {
    const lat = Number(req.query.lat);
    const lon = Number(req.query.lon);
    const radius = Math.min(Number(req.query.radius) || 3000, MAX_RADIUS_METERS);

    if (!Number.isFinite(lat) || !Number.isFinite(lon)) {
      res.status(400).json({error: 'lat and lon query parameters are required'});
      return;
    }

    try {
      const data = await fetchFromOverpass(buildQuery(lat, lon, radius));
      res.set('Cache-Control', 'public, max-age=120');
      res.status(200).json(data);
    } catch (err) {
      logger.error('All Overpass endpoints failed', err);
      res.status(502).json({error: 'Overpass unavailable'});
    }
  },
);
