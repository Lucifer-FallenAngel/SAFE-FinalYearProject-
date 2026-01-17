const axios = require('axios');
const fs = require('fs');
const FormData = require('form-data');

const VT_API_KEY = process.env.VT_API_KEY;

/* ============================================================
   URL REGEX
============================================================ */
const urlRegex = /(https?:\/\/[^\s]+|www\.[^\s]+)/gi;

/* ============================================================
   EXTRACT URLS FROM TEXT
============================================================ */
function extractUrls(text) {
  if (!text) return [];
  return text.match(urlRegex) || [];
}

/* ============================================================
   EXTRACT PER-VENDOR RESULTS (FOR UI REPORT)
============================================================ */
function extractVendorResults(analysisResults) {
  if (!analysisResults) return [];

  return Object.entries(analysisResults).map(([vendor, data]) => ({
    vendor,
    category: data.category || 'undetected', // malicious | suspicious | harmless
    result: data.result || null,              // phishing | malware | trojan | null
  }));
}

/* ============================================================
   SCAN URL USING VIRUSTOTAL
============================================================ */
async function scanUrl(url) {
  try {
    if (!VT_API_KEY) {
      return {
        isSafe: true,
        positives: 0,
        malicious: 0,
        suspicious: 0,
        total: 0,
        scan_url: null,
        source: 'disabled',
      };
    }

    const normalizedUrl = url.startsWith('http')
      ? url
      : `http://${url}`;

    const submitRes = await axios.post(
      'https://www.virustotal.com/api/v3/urls',
      new URLSearchParams({ url: normalizedUrl }),
      {
        headers: {
          'x-apikey': VT_API_KEY,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
      }
    );

    const analysisId = submitRes.data.data.id;

    await new Promise((r) => setTimeout(r, 8000));

    const reportRes = await axios.get(
      `https://www.virustotal.com/api/v3/analyses/${analysisId}`,
      { headers: { 'x-apikey': VT_API_KEY } }
    );

    const stats = reportRes.data.data.attributes.stats;

    const malicious = stats.malicious || 0;
    const suspicious = stats.suspicious || 0;
    const positives = malicious + suspicious;

    return {
      isSafe: positives === 0,
      positives,
      malicious,
      suspicious,
      total: Object.values(stats).reduce((a, b) => a + b, 0),
      scan_url: `https://www.virustotal.com/gui/url/${analysisId}`,
      source: 'url',
    };
  } catch (err) {
    console.error('VirusTotal URL scan error:', err.message);
    return {
      isSafe: true,
      positives: 0,
      malicious: 0,
      suspicious: 0,
      total: 0,
      scan_url: null,
      error: true,
      source: 'error',
    };
  }
}

/* ============================================================
   SCAN FILE BY HASH (PRIMARY – PRIVACY SAFE)
============================================================ */
async function scanFileHash(hash) {
  try {
    if (!VT_API_KEY) {
      return {
        isSafe: true,
        positives: 0,
        malicious: 0,
        suspicious: 0,
        total: 0,
        scan_url: null,
        source: 'disabled',
      };
    }

    const res = await axios.get(
      `https://www.virustotal.com/api/v3/files/${hash}`,
      {
        headers: { 'x-apikey': VT_API_KEY },
      }
    );

    const stats = res.data.data.attributes.last_analysis_stats;

    const malicious = stats.malicious || 0;
    const suspicious = stats.suspicious || 0;
    const positives = malicious + suspicious;

    return {
      isSafe: positives === 0,
      positives,
      malicious,
      suspicious,
      total: Object.values(stats).reduce((a, b) => a + b, 0),
      scan_url: `https://www.virustotal.com/gui/file/${hash}`,
      source: 'hash',
    };
  } catch (err) {
    // 🟡 Hash not found → unknown file
    if (err.response?.status === 404) {
      return {
        isSafe: true,
        positives: 0,
        malicious: 0,
        suspicious: 0,
        total: 0,
        scan_url: null,
        unknown: true,
        source: 'hash',
      };
    }

    console.error('VirusTotal hash scan error:', err.message);
    return {
      isSafe: true,
      positives: 0,
      malicious: 0,
      suspicious: 0,
      total: 0,
      scan_url: null,
      error: true,
      source: 'hash-error',
    };
  }
}

/* ============================================================
   FALLBACK: UPLOAD FILE TO VIRUSTOTAL (USER-APPROVED)
============================================================ */
async function scanFileByUpload(filePath) {
  try {
    if (!VT_API_KEY) {
      return {
        isSafe: true,
        positives: 0,
        malicious: 0,
        suspicious: 0,
        total: 0,
        scan_url: null,
        source: 'disabled',
      };
    }

    const form = new FormData();
    form.append('file', fs.createReadStream(filePath));

    const uploadRes = await axios.post(
      'https://www.virustotal.com/api/v3/files',
      form,
      {
        headers: {
          'x-apikey': VT_API_KEY,
          ...form.getHeaders(),
        },
        maxBodyLength: Infinity,
        maxContentLength: Infinity,
      }
    );

    const analysisId = uploadRes.data.data.id;

    await new Promise((r) => setTimeout(r, 15000));

    const reportRes = await axios.get(
      `https://www.virustotal.com/api/v3/analyses/${analysisId}`,
      {
        headers: { 'x-apikey': VT_API_KEY },
      }
    );

    const stats = reportRes.data.data.attributes.stats;

    const malicious = stats.malicious || 0;
    const suspicious = stats.suspicious || 0;
    const positives = malicious + suspicious;

    return {
      isSafe: positives === 0,
      positives,
      malicious,
      suspicious,
      total: Object.values(stats).reduce((a, b) => a + b, 0),
      scan_url: `https://www.virustotal.com/gui/file/${analysisId}`,
      source: 'upload',
    };
  } catch (err) {
    console.error('VirusTotal upload scan error:', err.message);
    return {
      isSafe: true,
      positives: 0,
      malicious: 0,
      suspicious: 0,
      total: 0,
      scan_url: null,
      error: true,
      source: 'upload-error',
    };
  }
}

/* ============================================================
   EXPORTS
============================================================ */
module.exports = {
  extractUrls,
  scanUrl,
  scanFileHash,
  scanFileByUpload,
  extractVendorResults, // ✅ NEW
};

