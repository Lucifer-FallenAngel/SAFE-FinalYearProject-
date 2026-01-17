const axios = require('axios');

const {
  scanUrl,
  scanFileHash,
  scanFileByUpload,
  extractVendorResults,
} = require('../utils/virusTotal');

// 🔹 Cache helpers (YOU MUST CREATE utils/scan_cache.js)
const {
  getCachedScan,
  saveScanResult,
} = require('../utils/scan_cache');

const VT_API_KEY = process.env.VT_API_KEY;

/* ============================================================
   HELPERS
============================================================ */

// VirusTotal URL-safe base64 (NO padding)
function vtBase64Url(url) {
  return Buffer.from(url)
    .toString('base64')
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_');
}


/* ============================================================
   ENRICH URL SCAN (WITH CACHE + VENDOR RESULTS)
============================================================ */
async function enrichUrlScan(url) {
  // 1️⃣ CHECK CACHE FIRST
  const cached = await getCachedScan('url', url);
  if (cached) {
    return {
      ...cached.result,
      cached: true,
    };
  }

  // 2️⃣ BASE SCAN
  const base = await scanUrl(url);

  // Disabled / error-safe fallback
  if (!VT_API_KEY || base.source === 'disabled' || base.error) {
    return base;
  }

  try {
    const encodedUrl = vtBase64Url(url);

    const res = await axios.get(
      `https://www.virustotal.com/api/v3/urls/${encodedUrl}`,
      {
        headers: { 'x-apikey': VT_API_KEY },
      }
    );

    const analysis =
      res.data.data.attributes.last_analysis_results || {};

    const enriched = {
      ...base,
      vendors: extractVendorResults(analysis),
    };

    // 3️⃣ SAVE TO CACHE
    await saveScanResult('url', url, enriched);

    return {
      ...enriched,
      cached: false,
    };
  } catch (err) {
    console.error('VT URL enrich error:', err.message);
    return base;
  }
}

/* ============================================================
   ENRICH FILE SCAN (CACHE → HASH → UPLOAD → VENDORS)
============================================================ */
async function enrichFileScan(hash, filePath, allowUpload = false) {
  // 1️⃣ CHECK CACHE FIRST (BY HASH)
  const cached = await getCachedScan('file', hash);
  if (cached) {
    return {
      ...cached.result,
      cached: true,
    };
  }

  // 2️⃣ HASH SCAN
  let base = await scanFileHash(hash);

  // 🟡 Unknown hash → optional upload fallback
  if (base.unknown && allowUpload && filePath) {
    base = await scanFileByUpload(filePath);
  }

  if (!VT_API_KEY || base.error) {
    return base;
  }

  try {
    const res = await axios.get(
      `https://www.virustotal.com/api/v3/files/${hash}`,
      {
        headers: { 'x-apikey': VT_API_KEY },
      }
    );

    const analysis =
      res.data.data.attributes.last_analysis_results || {};

    const enriched = {
      ...base,
      vendors: extractVendorResults(analysis),
    };

    // 3️⃣ SAVE TO CACHE
    await saveScanResult('file', hash, enriched);

    return {
      ...enriched,
      cached: false,
    };
  } catch (err) {
    console.error('VT file enrich error:', err.message);
    return base;
  }
}

/* ============================================================
   EXPORTS
============================================================ */
module.exports = {
  enrichUrlScan,
  enrichFileScan,
};
