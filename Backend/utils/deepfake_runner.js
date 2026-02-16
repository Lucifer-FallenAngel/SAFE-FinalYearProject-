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

    // 🔥 IMPORTANT FIXES
    const pythonCwd = path.dirname(scriptPath);
    const absoluteImagePath = path.resolve(imagePath);

    const PYTHON_BIN =
      '/Library/Frameworks/Python.framework/Versions/3.11/bin/python3';

    const py = spawn(
      PYTHON_BIN,
      [scriptPath, absoluteImagePath],
      {
        cwd: pythonCwd,
      }
    );


    let output = '';
    let errorOutput = '';

    py.stdout.on('data', (data) => {
      output += data.toString();
    });

    py.stderr.on('data', (data) => {
      errorOutput += data.toString();
    });

    py.on('close', (code) => {
      console.log('🐍 Python exited with code:', code);
      console.log('🐍 PY STDOUT:', output);
      console.log('🐍 PY STDERR:', errorOutput);
    try {
      const jsonMatch = output.match(/\{[\s\S]*?\}/);
      if (!jsonMatch) {
        throw new Error('No JSON found in output');
      }
      const parsed = JSON.parse(jsonMatch[0]);
      resolve(parsed);
    } catch (err) {
      console.error('Deepfake parse error');
      console.error('STDOUT:', output);
      console.error('STDERR:', errorOutput);
      resolve(null); // do NOT crash upload
    }
  });
  });
}

module.exports = { runDeepfakeDetection };
