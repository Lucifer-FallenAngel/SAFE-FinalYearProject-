const axios = require('axios');

const {
  scanUrl,
  scanFileHash,
  scanFileByUpload,
  extractVendorResults,
} = require('../utils/virusTotal');

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

// 🔥 Normalize VT analysis into FULL readable result
function normalizeAnalysis(analysisResults = {}, stats = {}) {
  const vendors = [];
  const malwareTypes = new Set();

  for (const [vendor, r] of Object.entries(analysisResults)) {
    if (r.category === 'malicious' || r.category === 'suspicious') {
      vendors.push({
        vendor,
        category: r.category,
        result: r.result || 'unknown',
        engine_version: r.engine_version,
        method: r.method,
      });

      if (r.result) {
        const res = r.result.toLowerCase();
        if (res.includes('trojan')) malwareTypes.add('trojan');
        if (res.includes('phishing')) malwareTypes.add('phishing');
        if (res.includes('worm')) malwareTypes.add('worm');
        if (res.includes('ransom')) malwareTypes.add('ransomware');
        if (res.includes('spy')) malwareTypes.add('spyware');
        if (res.includes('adware')) malwareTypes.add('adware');
        if (res.includes('backdoor')) malwareTypes.add('backdoor');
        if (res.includes('exploit')) malwareTypes.add('exploit');
      }
    }
  }

  const positives =
    (stats.malicious || 0) + (stats.suspicious || 0);

  return {
    isSafe: positives === 0,
    positives,
    totalEngines: Object.keys(analysisResults).length,
    stats,
    malwareTypes: Array.from(malwareTypes),
    vendors,
  };
}

/* ============================================================
   ENRICH URL SCAN (CACHE + FULL VENDOR DATA)
============================================================ */
async function enrichUrlScan(url) {
  // 1️⃣ CACHE CHECK
  const cached = await getCachedScan('url', url);
  if (cached) {
    return {
      ...cached.result,
      cached: true,
    };
  }

  // 2️⃣ BASE SCAN
  const base = await scanUrl(url);

  if (!VT_API_KEY || base.source === 'disabled' || base.error) {
    return base;
  }

  try {
    const encodedUrl = vtBase64Url(url);

    const res = await axios.get(
      `https://www.virustotal.com/api/v3/urls/${encodedUrl}`,
      { headers: { 'x-apikey': VT_API_KEY } }
    );

    const attrs = res.data?.data?.attributes || {};
    const analysis = attrs.last_analysis_results || {};
    const stats = attrs.last_analysis_stats || {};

    const normalized = normalizeAnalysis(analysis, stats);

    const enriched = {
      ...base,
      ...normalized,
      raw: undefined, // keep payload light
    };

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
   ENRICH FILE SCAN (CACHE → HASH → UPLOAD → FULL REPORT)
============================================================ */
async function enrichFileScan(hash, filePath, allowUpload = false) {
  // 1️⃣ CACHE CHECK
  const cached = await getCachedScan('file', hash);
  if (cached) {
    return {
      ...cached.result,
      cached: true,
    };
  }

  // 2️⃣ HASH SCAN
  let base = await scanFileHash(hash);

  // 🟡 Unknown hash → optional upload
  if (base.unknown && allowUpload && filePath) {
    base = await scanFileByUpload(filePath);
  }

  if (!VT_API_KEY || base.error) {
    return base;
  }

  try {
    const res = await axios.get(
      `https://www.virustotal.com/api/v3/files/${hash}`,
      { headers: { 'x-apikey': VT_API_KEY } }
    );

    const attrs = res.data?.data?.attributes || {};
    const analysis = attrs.last_analysis_results || {};
    const stats = attrs.last_analysis_stats || {};

    const normalized = normalizeAnalysis(analysis, stats);

    const enriched = {
      ...base,
      ...normalized,
      raw: undefined,
    };

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
