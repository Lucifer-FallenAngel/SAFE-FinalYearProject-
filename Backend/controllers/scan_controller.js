const {
  enrichUrlScan,
  enrichFileScan,
} = require('../services/virustotal_service');

exports.scanUrlController = async (req, res) => {
  try {
    const { url } = req.body;
    const result = await enrichUrlScan(url);
    res.json(result);
  } catch {
    res.status(500).json({ error: true });
  }
};

exports.scanFileController = async (req, res) => {
  try {
    const { hash, allow_upload } = req.body;
    const filePath = req.file?.path;

    const result = await enrichFileScan(
      hash,
      filePath,
      allow_upload === 'true'
    );

    res.json(result);
  } catch {
    res.status(500).json({ error: true });
  }
};
