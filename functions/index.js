const {onRequest} = require('firebase-functions/v2/https');
const logger = require('firebase-functions/logger');
const {initializeApp} = require('firebase-admin/app');
const {getAuth} = require('firebase-admin/auth');
const vision = require('@google-cloud/vision');

initializeApp();

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

async function fetchOne(endpoint, query, timeoutMs) {
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
    signal: AbortSignal.timeout(timeoutMs),
  });
  if (!response.ok) {
    const bodySnippet = (await response.text().catch(() => '')).slice(0, 300);
    logger.error('Overpass endpoint returned non-OK status', {
      endpoint,
      status: response.status,
      statusText: response.statusText,
      bodySnippet,
    });
    throw new Error(`${endpoint} responded ${response.status}`);
  }
  return response.json();
}

/// Races every Overpass endpoint at once and takes whichever answers first,
/// instead of trying them one after another. Overpass is free community
/// infra with no SLA — plain slowness (not just outright errors) is normal
/// — so waiting out a slow instance when a working one already answered
/// would just be wasted latency. Only fails if every endpoint does.
async function fetchFromOverpass(query) {
  const attempts = OVERPASS_ENDPOINTS.map((endpoint) =>
    fetchOne(endpoint, query, 10000).catch((err) => {
      logger.error('Overpass endpoint failed', {endpoint, error: String(err)});
      throw err;
    }),
  );
  try {
    return await Promise.any(attempts);
  } catch {
    throw new Error('All Overpass endpoints failed');
  }
}

/**
 * GET /nearbyStores?lat=..&lon=..&radius=..
 * Proxies an Overpass "grocery stores near me" query and returns the raw
 * Overpass JSON response unchanged — filtering/normalizing store names stays
 * on the Dart side (StoreLocatorService) so there's one place that logic
 * lives.
 */
// Created lazily, not at module load - constructing it eagerly here made
// `firebase deploy`'s local analysis step (which loads this file in a
// sandboxed environment with no real credentials available yet) hang until
// it timed out, since the client tries to resolve credentials as soon as
// it's built.
let _visionClient;
function getVisionClient() {
  _visionClient ??= new vision.ImageAnnotatorClient();
  return _visionClient;
}

// A photographed receipt easily fits well under this (base64 inflates raw
// bytes by ~33%) - this exists purely to reject an absurdly large upload
// before it reaches the (paid) Vision API, not to constrain normal use.
const MAX_IMAGE_BASE64_LENGTH = 10_000_000;

/**
 * POST /receiptOcr { imageBase64: string }
 * Header: Authorization: Bearer <Firebase ID token>
 *
 * Recognizes text in a photographed receipt via Google Cloud Vision's
 * document-text-detection (tuned for dense text documents, unlike the
 * generic text-detection feature). Exists only because on-device OCR
 * (google_mlkit_text_recognition, used directly on Android/iOS - see
 * OcrService) has no web implementation at all - ML Kit is a native SDK,
 * not something Google ships for browsers - so web needed a server-side
 * equivalent to support the same "take a photo, get it read" flow.
 *
 * Requires a valid Firebase Auth token (anonymous sessions included) so
 * this paid-per-call API isn't reachable by an arbitrary caller with no
 * relationship to the app at all - not a strong abuse defense on its own,
 * but a meaningful floor above "wide open".
 */
exports.receiptOcr = onRequest(
  {region: 'europe-west1', cors: true, timeoutSeconds: 30, memory: '256MiB'},
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).json({error: 'POST only'});
      return;
    }

    const authHeader = req.get('Authorization') || '';
    const tokenMatch = authHeader.match(/^Bearer (.+)$/);
    if (!tokenMatch) {
      res.status(401).json({error: 'Missing Authorization bearer token'});
      return;
    }
    try {
      await getAuth().verifyIdToken(tokenMatch[1]);
    } catch (err) {
      logger.warn('receiptOcr rejected an invalid auth token', {error: String(err)});
      res.status(401).json({error: 'Invalid auth token'});
      return;
    }

    const imageBase64 = req.body && req.body.imageBase64;
    if (!imageBase64 || typeof imageBase64 !== 'string') {
      res.status(400).json({error: 'imageBase64 is required'});
      return;
    }
    if (imageBase64.length > MAX_IMAGE_BASE64_LENGTH) {
      res.status(413).json({error: 'Image too large'});
      return;
    }

    try {
      const [result] = await getVisionClient().documentTextDetection({
        image: {content: imageBase64},
      });
      const text = (result.fullTextAnnotation && result.fullTextAnnotation.text) || '';
      res.status(200).json({text});
    } catch (err) {
      logger.error('Cloud Vision request failed', err);
      res.status(502).json({error: 'OCR unavailable'});
    }
  },
);

exports.nearbyStores = onRequest(
  {region: 'europe-west1', cors: true, timeoutSeconds: 20, memory: '256MiB'},
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
