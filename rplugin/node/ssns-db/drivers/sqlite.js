const initSqlJs = require('sql.js');
const fs = require('fs');
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
  constructor(connectionString) {
    super(connectionString);
    this.dbPath = this.parseConnectionString();
    this.db = null;
    this.SQL = null;
  }

  /**
   * Parse SQLite connection string
   * Formats:
   *   sqlite://./path/to/database.db
   *   sqlite:///absolute/path/to/database.db
   *   sqlite://C:/path/to/database.db (Windows)
   *
   * @returns {string} File path to database
   */
  parseConnectionString() {
    const connStr = this.connectionString;

    console.error('[DEBUG] SQLite connection string:', connStr);

    // Remove sqlite:// prefix
    let path = connStr.replace(/^sqlite:\/\//, '');

    // Handle different path formats
    if (path.startsWith('/') && path[2] === ':') {
      // Windows absolute path: /C:/path/to/db.db -> C:/path/to/db.db
      path = path.substring(1);
    } else if (path.startsWith('//')) {
      // Unix absolute path: //path/to/db.db -> /path/to/db.db
      path = path.substring(1);
    }

    // Default to in-memory if no path
    if (!path || path === ':memory:') {
      path = ':memory:';
    }

    console.error('[DEBUG] SQLite database path:', path);
    return path;
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
        const stmt = this.db.prepare(query);
        const rows = stmt.all();

        return {
          columns: rows.map(row => ({
            name: row.name,
            type: row.type,
            nullable: row.notnull === 0,
            defaultValue: row.dflt_value,
            isPrimaryKey: row.pk === 1,
            isForeignKey: false, // Need separate query for FK info
          }))
        };
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
