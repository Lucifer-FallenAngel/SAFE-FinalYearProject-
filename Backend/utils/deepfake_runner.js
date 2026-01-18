const { spawn } = require('child_process');
const path = require('path');

/**
 * Runs Python deepfake detection script
 * @param {string} imagePath
 * @returns {Promise<{isFake:boolean, confidence:number}>}
 */
function runDeepfakeDetection(imagePath) {
  return new Promise((resolve, reject) => {
    const scriptPath = path.join(__dirname, '../deepfake_service.py');

    const py = spawn('python3', [scriptPath, imagePath]);

    let output = '';
    let errorOutput = '';

    py.stdout.on('data', (data) => {
      output += data.toString();
    });

    py.stderr.on('data', (data) => {
      errorOutput += data.toString();
    });

    py.on('close', () => {
      try {
        const lastLine = output.trim().split('\n').pop();
        const parsed = JSON.parse(lastLine);
        resolve(parsed);
      } catch (err) {
        console.error('Deepfake parse error:', output, errorOutput);
        reject(err);
      }
    });
  });
}

module.exports = { runDeepfakeDetection };
