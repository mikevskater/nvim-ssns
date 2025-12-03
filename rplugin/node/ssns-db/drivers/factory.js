/**
 * Driver Factory - Auto-detect and create the appropriate database driver
 *
 * Supports:
 * - SQL Server (sqlserver://)
 * - MySQL (mysql://)
 * - SQLite (sqlite://)
 * - PostgreSQL (postgres:// or postgresql://) - when implemented
*/
const { ssnsLog } = require('../ssns-log');
const SqlServerDriver = require('./sqlserver');
const MySQLDriver = require('./mysql');
const SQLiteDriver = require('./sqlite');
const PostgresDriver = require('./postgres');

/**
 * Get the appropriate driver for a connection string
 *
 * @param {string} connectionString - Database connection string
 * @returns {BaseDriver} Driver instance
 * @throws {Error} If connection string format is invalid or unsupported
 */
function getDriver(connectionString) {
  ssnsLog(`[factory] getDriver called with: ${connectionString}`);
  if (!connectionString || typeof connectionString !== 'string') {
    ssnsLog('[factory] Invalid connection string: must be a non-empty string');
    throw new Error('Invalid connection string: must be a non-empty string');
  }

  const connStr = connectionString.toLowerCase();

  // SQL Server
  if (connStr.startsWith('sqlserver://') || connStr.startsWith('mssql://')) {
    ssnsLog('[factory] Detected SQL Server connection string');
    return new SqlServerDriver(connectionString);
  }

  // MySQL
  if (connStr.startsWith('mysql://')) {
    ssnsLog('[factory] Detected MySQL connection string');
    return new MySQLDriver(connectionString);
  }

  // SQLite
  if (connStr.startsWith('sqlite://')) {
    ssnsLog('[factory] Detected SQLite connection string');
    return new SQLiteDriver(connectionString);
  }

  // PostgreSQL
  if (connStr.startsWith('postgres://') || connStr.startsWith('postgresql://')) {
    ssnsLog('[factory] Detected PostgreSQL connection string');
    return new PostgresDriver(connectionString);
  }

  // Unknown database type
  ssnsLog(`[factory] Unsupported database type in connection string: ${connectionString}`);
  throw new Error(
    `Unsupported database type in connection string: ${connectionString}\n` +
    `Supported formats:\n` +
    `  - sqlserver://server/database\n` +
    `  - mysql://user:pass@host/database\n` +
    `  - sqlite://./path/to/database.db\n` +
    `  - postgres://... (coming soon)`
  );
}

/**
 * Detect database type from connection string
 *
 * @param {string} connectionString - Database connection string
 * @returns {string} Database type ('sqlserver', 'mysql', 'sqlite', 'postgres', 'unknown')
 */
function detectDatabaseType(connectionString) {
  ssnsLog(`[factory] detectDatabaseType called with: ${connectionString}`);
  if (!connectionString || typeof connectionString !== 'string') {
    ssnsLog('[factory] Invalid connection string for detectDatabaseType');
    return 'unknown';
  }

  const connStr = connectionString.toLowerCase();

  if (connStr.startsWith('sqlserver://') || connStr.startsWith('mssql://')) {
    ssnsLog('[factory] Detected type: sqlserver');
    return 'sqlserver';
  }

  if (connStr.startsWith('mysql://')) {
    ssnsLog('[factory] Detected type: mysql');
    return 'mysql';
  }

  if (connStr.startsWith('sqlite://')) {
    ssnsLog('[factory] Detected type: sqlite');
    return 'sqlite';
  }

  if (connStr.startsWith('postgres://') || connStr.startsWith('postgresql://')) {
    ssnsLog('[factory] Detected type: postgres');
    return 'postgres';
  }

  ssnsLog('[factory] Unknown database type');
  return 'unknown';
}

/**
 * Check if a database type is supported
 *
 * @param {string} dbType - Database type to check
 * @returns {boolean} True if supported
 */
function isSupported(dbType) {
  ssnsLog(`[factory] isSupported called with: ${dbType}`);
  const supported = ['sqlserver', 'mysql', 'sqlite'];
  const result = supported.includes(dbType.toLowerCase());
  ssnsLog(`[factory] isSupported result: ${result}`);
  return result;
}

/**
 * Get list of supported database types
 *
 * @returns {Array<string>} List of supported database types
 */
function getSupportedTypes() {
  ssnsLog('[factory] getSupportedTypes called');
  return ['sqlserver', 'mysql', 'sqlite', 'postgres'];
}

module.exports = {
  getDriver,
  detectDatabaseType,
  isSupported,
  getSupportedTypes
};
