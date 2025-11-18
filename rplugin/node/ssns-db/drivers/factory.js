/**
 * Driver Factory - Auto-detect and create the appropriate database driver
 *
 * Supports:
 * - SQL Server (sqlserver://)
 * - MySQL (mysql://)
 * - SQLite (sqlite://)
 * - PostgreSQL (postgres:// or postgresql://) - when implemented
 */

const SqlServerDriver = require('./sqlserver');
const MySQLDriver = require('./mysql');
const SQLiteDriver = require('./sqlite');

/**
 * Get the appropriate driver for a connection string
 *
 * @param {string} connectionString - Database connection string
 * @returns {BaseDriver} Driver instance
 * @throws {Error} If connection string format is invalid or unsupported
 */
function getDriver(connectionString) {
  if (!connectionString || typeof connectionString !== 'string') {
    throw new Error('Invalid connection string: must be a non-empty string');
  }

  const connStr = connectionString.toLowerCase();

  // SQL Server
  if (connStr.startsWith('sqlserver://') || connStr.startsWith('mssql://')) {
    return new SqlServerDriver(connectionString);
  }

  // MySQL
  if (connStr.startsWith('mysql://')) {
    return new MySQLDriver(connectionString);
  }

  // SQLite
  if (connStr.startsWith('sqlite://')) {
    return new SQLiteDriver(connectionString);
  }

  // PostgreSQL (future support)
  if (connStr.startsWith('postgres://') || connStr.startsWith('postgresql://')) {
    throw new Error('PostgreSQL support not yet implemented. Coming in Phase 8.1!');
  }

  // Unknown database type
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
  if (!connectionString || typeof connectionString !== 'string') {
    return 'unknown';
  }

  const connStr = connectionString.toLowerCase();

  if (connStr.startsWith('sqlserver://') || connStr.startsWith('mssql://')) {
    return 'sqlserver';
  }

  if (connStr.startsWith('mysql://')) {
    return 'mysql';
  }

  if (connStr.startsWith('sqlite://')) {
    return 'sqlite';
  }

  if (connStr.startsWith('postgres://') || connStr.startsWith('postgresql://')) {
    return 'postgres';
  }

  return 'unknown';
}

/**
 * Check if a database type is supported
 *
 * @param {string} dbType - Database type to check
 * @returns {boolean} True if supported
 */
function isSupported(dbType) {
  const supported = ['sqlserver', 'mysql', 'sqlite'];
  return supported.includes(dbType.toLowerCase());
}

/**
 * Get list of supported database types
 *
 * @returns {Array<string>} List of supported database types
 */
function getSupportedTypes() {
  return ['sqlserver', 'mysql', 'sqlite'];
}

module.exports = {
  getDriver,
  detectDatabaseType,
  isSupported,
  getSupportedTypes
};
