const express = require('express');
const multer = require('multer');

const {
  scanUrlController,
  scanFileController,
} = require('../controllers/scan_controller');

const router = express.Router();

/* ============================================================
   MULTER SETUP (TEMP FILE STORAGE)
============================================================ */
const upload = multer({
  dest: 'uploads/tmp',
  limits: {
    fileSize: 25 * 1024 * 1024, // 25MB (VirusTotal limit safe)
  },
});

/* ============================================================
   ROUTES
============================================================ */

// 🔗 URL Scan (returns full vendor report)
router.post('/url', scanUrlController);

// 📁 File Scan (hash OR upload fallback)
router.post('/file', upload.single('file'), scanFileController);

module.exports = router;
