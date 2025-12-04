const initSqlJs = require('sql.js');
const fs = require('fs');
const path = require('path');
const BaseDriver = require('./base');

/**
 * SQLiteDriver - SQLite database driver using sql.js package
 *
 * Provides SQLite connectivity with:
 * - WebAssembly-based SQLite (no native compilation needed)
 * - File-based connections
 * - No connection pooling needed (single-file database)
 * - Structured errors
 */
class SQLiteDriver extends BaseDriver {
  /**
   * @param {Object} config - Connection configuration object
   * @param {string} config.type - "sqlite"
   * @param {Object} config.server - Server details (for SQLite, contains file path)
   * @param {string} [config.server.database] - Path to SQLite database file (or :memory:)
   * @param {string} [config.server.host] - Alternative: file path in host field
   */
  constructor(config) {
    super(config);
    this.dbPath = this.getSqliteFilePath(config);
    this.db = null;
    this.SQL = null;
  }

  /**
   * Extract SQLite file path from config
   *
   * @param {Object} config - Connection configuration
   * @returns {string} File path to database
   */
  getSqliteFilePath(config) {
    const server = config.server || {};

    // Try database field first, then host (for flexibility)
    let dbPath = server.database || server.host || ':memory:';

    console.error('[DEBUG] SQLite database path:', dbPath);

    // Handle Windows paths
    if (process.platform === 'win32' && dbPath.startsWith('/')) {
      // Convert /C:/path to C:/path
      if (dbPath.length > 2 && dbPath[2] === ':') {
        dbPath = dbPath.substring(1);
      }
    }

    // Default to in-memory if empty
    if (!dbPath || dbPath === '') {
      dbPath = ':memory:';
    }

    return dbPath;
  }

  /**
   * Establish connection (open database file)
   */
  async connect() {
    if (this.isConnected && this.db) {
      return; // Already connected
    }

    try {
      // Initialize sql.js
      this.SQL = await initSqlJs();

      // Load database from file or create new
      if (this.dbPath === ':memory:') {
        // In-memory database
        this.db = new this.SQL.Database();
      } else {
        // File-based database
        if (fs.existsSync(this.dbPath)) {
          // Load existing database
          const buffer = fs.readFileSync(this.dbPath);
          this.db = new this.SQL.Database(buffer);
        } else {
          // Create new database file
          this.db = new this.SQL.Database();
        }
      }

      // Enable foreign keys
      this.db.run('PRAGMA foreign_keys = ON');

      this.isConnected = true;
    } catch (err) {
      this.isConnected = false;
      throw new Error(`SQLite connection failed: ${err.message}`);
    }
  }

  /**
   * Close database connection
   */
  async disconnect() {
    if (this.db) {
      // Save database to file if not in-memory
      if (this.dbPath !== ':memory:') {
        const data = this.db.export();
        fs.writeFileSync(this.dbPath, data);
      }

      this.db.close();
      this.db = null;
      this.isConnected = false;
    }
  }

  /**
   * Execute SQL query with structured result sets
   *
   * Note: sql.js executes synchronously, but we return a Promise
   * for consistency with other drivers
   *
   * @param {string} query - SQL query to execute
   * @param {Object} options - Execution options
   * @returns {Promise<Object>} Structured result object
   */
  async execute(query, options = {}) {
    const startTime = Date.now();

    try {
      // Ensure connection
      if (!this.isConnected) {
        await this.connect();
      }

      // sql.js can execute multiple statements with exec()
      const results = this.db.exec(query);

      const resultSets = [];

      if (results.length === 0) {
        // No results (INSERT/UPDATE/DELETE)
        resultSets.push({
          columns: {},
          rows: [],
          rowCount: this.db.getRowsModified()
        });
      } else {
        // Process each result set
        for (const result of results) {
          const columns = {};
          const rows = [];

          // Build column metadata
          result.columns.forEach((colName, index) => {
            columns[colName] = {
              index: index,
              name: colName,
              type: 'unknown', // sql.js doesn't provide type info
              nullable: true
            };
          });

          // Build row objects
          result.values.forEach(valueArray => {
            const row = {};
            result.columns.forEach((colName, index) => {
              row[colName] = valueArray[index];
            });
            rows.push(row);
          });

          resultSets.push({
            columns: columns,
            rows: rows,
            rowCount: rows.length
          });
        }
      }

      const endTime = Date.now();
      const executionTime = endTime - startTime;

      // Save database after modifications
      if (this.dbPath !== ':memory:' && resultSets.some(rs => rs.rowCount > 0)) {
        const data = this.db.export();
        fs.writeFileSync(this.dbPath, data);
      }

      return {
        resultSets: resultSets,
        metadata: {
          executionTime: executionTime,
          rowsAffected: resultSets.map(rs => rs.rowCount)
        },
        error: null
      };

    } catch (err) {
      const endTime = Date.now();
      const executionTime = endTime - startTime;

      return {
        resultSets: [],
        metadata: {
          executionTime: executionTime,
          rowsAffected: []
        },
        error: {
          message: err.message || 'Unknown error',
          code: err.code || null,
          lineNumber: null, // SQLite doesn't provide line numbers
          procName: null
        }
      };
    }
  }

  /**
   * Infer SQLite type from JavaScript value
   */
  inferType(value) {
    if (value === null) return 'null';
    if (typeof value === 'number') {
      return Number.isInteger(value) ? 'integer' : 'real';
    }
    if (typeof value === 'string') return 'text';
    if (Buffer.isBuffer(value)) return 'blob';
    return 'unknown';
  }

  /**
   * Get metadata for database object (for IntelliSense)
   */
  async getMetadata(objectType, objectName, schemaName = null) {
    try {
      if (!this.isConnected) {
        await this.connect();
      }

      if (objectType === 'table' || objectType === 'view') {
        // Query SQLite system tables for column metadata
        const query = `PRAGMA table_info(${objectName})`;
        const results = this.db.exec(query);

        if (results.length === 0 || results[0].values.length === 0) {
          return { columns: [] };
        }

        // PRAGMA table_info returns: cid, name, type, notnull, dflt_value, pk
        const columns = results[0].values.map(row => ({
          name: row[1],
          type: row[2],
          nullable: row[3] === 0,
          defaultValue: row[4],
          isPrimaryKey: row[5] === 1,
          isForeignKey: false, // Need separate query for FK info
        }));

        return { columns };
      }

      return { columns: [] };

    } catch (err) {
      throw new Error(`Failed to get metadata: ${err.message}`);
    }
  }

  /**
   * Get database type identifier
   * @returns {string}
   */
  getType() {
    return 'sqlite';
  }
}

module.exports = SQLiteDriver;
