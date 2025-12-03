const fs = require('fs');
const path = require('path');

// Log file path (matches the frontend log location)
const LOG_PATH = path.join(process.env.LOCALAPPDATA || process.env.HOME || '.', 'nvim-data', 'ssns_debug.log');

function getTimestamp() {
  const now = new Date();
  // Format: YYYY-MM-DD HH:mm:ss
  const pad = n => n.toString().padStart(2, '0');
  return `${now.getFullYear()}-${pad(now.getMonth()+1)}-${pad(now.getDate())} ${pad(now.getHours())}:${pad(now.getMinutes())}:${pad(now.getSeconds())}`;
}

/**
 * Log a message to the debug log file with [NODE] prefix and timestamp
 * @param {string} msg
 */
function ssnsLog(msg) {
  const line = `${getTimestamp()} [NODE] ${msg}`;
  try {
    fs.appendFileSync(LOG_PATH, line + '\n', { encoding: 'utf8' });
  } catch (e) {
    process.stderr.write(line + '\n');
  }
}

module.exports = { ssnsLog };
