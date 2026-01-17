const db = require('../models');
const ScanCache = db.ScanCache;

/* ============================================================
   CONFIG
============================================================ */

// Cache validity duration (in milliseconds)
// Example: 24 hours
const CACHE_TTL = 24 * 60 * 60 * 1000;

/* ============================================================
   CHECK IF CACHE IS STILL VALID
============================================================ */
function isCacheValid(lastScannedAt) {
  if (!lastScannedAt) return false;
  return Date.now() - new Date(lastScannedAt).getTime() < CACHE_TTL;
}

/* ============================================================
   GET CACHED SCAN (WITH TTL CHECK)
============================================================ */
async function getCachedScan(type, identifier) {
  const cached = await ScanCache.findOne({
    where: { type, identifier },
  });

  if (!cached) return null;

  if (!isCacheValid(cached.lastScannedAt)) {
    return null; // ❌ expired → force re-scan
  }

  return cached.result;
}

/* ============================================================
   SAVE / UPDATE SCAN RESULT
============================================================ */
async function saveScanResult(type, identifier, result) {
  await ScanCache.upsert({
    type,
    identifier,
    result,
    lastScannedAt: new Date(),
  });

  return result;
}

/* ============================================================
   OPTIONAL: CLEAR CACHE (ADMIN / DEBUG)
============================================================ */
async function clearCache(type = null) {
  if (type) {
    return await ScanCache.destroy({ where: { type } });
  }
  return await ScanCache.destroy({ where: {} });
}

/* ============================================================
   EXPORTS
============================================================ */
module.exports = {
  getCachedScan,
  saveScanResult,
  clearCache,
};
