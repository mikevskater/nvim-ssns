const { Pool } = require('pg');
const BaseDriver = require('./base');

/**
 * PostgresDriver - PostgreSQL database driver using pg package
 *
 * Provides PostgreSQL connectivity with:
 * - Connection pooling
 * - Promise-based API
 * - Structured errors
 * - Column metadata
 */
class PostgresDriver extends BaseDriver {
  constructor(connectionString) {
    super(connectionString);
    this.config = this.parseConnectionString();
    this.pool = null;
  }

  /**
   * Parse PostgreSQL connection string
   * Formats:
   *   postgres://host/database
   *   postgres://user:pass@host/database
   *   postgres://user:pass@host:port/database
   *   postgresql://user:pass@host:port/database
   *
   * @returns {Object} pg configuration object
   */
  parseConnectionString() {
    const connStr = this.connectionString;

    console.error('[DEBUG] PostgreSQL connection string:', connStr);

    // Remove postgres:// or postgresql:// prefix
    const cleaned = connStr.replace(/^(postgres|postgresql):\/\//, '');

    // Parse authentication (if present)
    let auth = null;
    let serverPart = cleaned;

    if (cleaned.includes('@')) {
      const parts = cleaned.split('@');
      const [user, password] = parts[0].split(':');
      auth = { user, password };
      serverPart = parts[1];
    }

    // Parse host, port, and database
    const [hostWithPort, database] = serverPart.split('/');
    let host = hostWithPort;
    let port = 5432; // Default PostgreSQL port

    if (hostWithPort.includes(':')) {
      const parts = hostWithPort.split(':');
      host = parts[0];
      port = parseInt(parts[1], 10);
    }

    // Build pg config
    const config = {
      host: host || 'localhost',
      port: port,
      database: database || 'postgres',
      max: 10,                    // Connection pool max size
      idleTimeoutMillis: 30000,   // Close idle connections after 30s
      connectionTimeoutMillis: 2000, // Connection timeout
    };

    if (auth) {
      config.user = auth.user;
      config.password = auth.password;
    } else {
      // Default to postgres user
      config.user = 'postgres';
      config.password = '';
    }

    console.error('[DEBUG] PostgreSQL config:', JSON.stringify(config, null, 2));
    return config;
  }

  /**
   * Establish connection pool
   */
  async connect() {
    if (this.isConnected && this.pool) {
      return; // Already connected
    }

    try {
      this.pool = new Pool(this.config);

      // Test connection
      const client = await this.pool.connect();
      client.release();

      this.isConnected = true;
    } catch (err) {
      this.isConnected = false;
      throw new Error(`PostgreSQL connection failed: ${err.message}`);
    }
  }

  /**
   * Close connection pool
   */
  async disconnect() {
    if (this.pool) {
      await this.pool.end();
      this.pool = null;
      this.isConnected = false;
    }
  }

  /**
   * Execute SQL query with structured result sets
   *
   * PostgreSQL's pg library supports multiple queries separated by semicolons.
   * For single query: result is an object { rows, fields, rowCount }
   * For multiple queries: result is an array of result objects
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

      // Execute query - pg supports multiple statements separated by semicolons
      const result = await this.pool.query(query);

      const endTime = Date.now();
      const executionTime = endTime - startTime;

      // Check if this is a single result or multiple results
      // pg@7.0+ returns an array for multiple statements
      const results = Array.isArray(result) ? result : [result];

      // Format each result set
      const resultSets = results.map(res => this.formatResultSet(res.rows, res.fields));

      return {
        resultSets: resultSets,
        metadata: {
          executionTime: executionTime,
          rowsAffected: results.map(res => res.rowCount || 0)
        },
        error: null
      };

    } catch (err) {
      const endTime = Date.now();
      const executionTime = endTime - startTime;

      // Parse PostgreSQL error
      const error = {
        message: err.message || 'Unknown error',
        code: err.code || null,
        lineNumber: err.position ? this.getLineFromPosition(query, err.position) : null,
        procName: null,
        severity: err.severity || null,
        detail: err.detail || null,
        hint: err.hint || null,
      };

      return {
        resultSets: [],
        metadata: {
          executionTime: executionTime,
          rowsAffected: []
        },
        error: error
      };
    }
  }

  /**
   * Convert character position to line number
   * @param {string} query - SQL query
   * @param {string} position - Character position
   * @returns {number|null} Line number
   */
  getLineFromPosition(query, position) {
    if (!position) return null;
    const pos = parseInt(position, 10);
    if (isNaN(pos)) return null;

    const lines = query.substring(0, pos).split('\n');
    return lines.length;
  }

  /**
   * Format a result set with column metadata
   */
  formatResultSet(rows, fields) {
    const columns = {};

    if (fields && fields.length > 0) {
      fields.forEach((field, index) => {
        columns[field.name] = {
          index: index,
          name: field.name,
          type: this.mapPostgresType(field.dataTypeID),
          tableID: field.tableID,
          columnID: field.columnID,
          dataTypeID: field.dataTypeID,
          nullable: true, // PostgreSQL doesn't provide this in query results
        };
      });
    }

    return {
      columns: columns,
      rows: rows || [],
      rowCount: rows ? rows.length : 0
    };
  }

  /**
   * Map PostgreSQL data type IDs to display strings
   * Common PostgreSQL type OIDs
   */
  mapPostgresType(typeId) {
    const types = {
      16: 'boolean',
      20: 'bigint',
      21: 'smallint',
      23: 'integer',
      25: 'text',
      700: 'real',
      701: 'double precision',
      1043: 'varchar',
      1082: 'date',
      1083: 'time',
      1114: 'timestamp',
      1184: 'timestamptz',
      1700: 'numeric',
      2950: 'uuid',
      3802: 'jsonb',
      114: 'json',
    };

    return types[typeId] || `oid(${typeId})`;
  }

  /**
   * Get metadata for database object (for IntelliSense)
   */
  async getMetadata(objectType, objectName, schemaName = 'public') {
    try {
      if (!this.isConnected) {
        await this.connect();
      }

      if (objectType === 'table' || objectType === 'view') {
        // Query PostgreSQL system catalogs for column metadata
        const query = `
          SELECT
            a.attname AS name,
            pg_catalog.format_type(a.atttypid, a.atttypmod) AS type,
            a.attnotnull AS not_null,
            pg_catalog.pg_get_expr(d.adbin, d.adrelid) AS default_value,
            a.attnum AS ordinal_position,
            (SELECT EXISTS (
              SELECT 1 FROM pg_constraint
              WHERE conrelid = a.attrelid
              AND contype = 'p'
              AND a.attnum = ANY(conkey)
            )) AS is_primary_key,
            (SELECT EXISTS (
              SELECT 1 FROM pg_constraint
              WHERE conrelid = a.attrelid
              AND contype = 'f'
              AND a.attnum = ANY(conkey)
            )) AS is_foreign_key
          FROM pg_catalog.pg_attribute a
          LEFT JOIN pg_catalog.pg_attrdef d ON (a.attrelid = d.adrelid AND a.attnum = d.adnum)
          JOIN pg_catalog.pg_class c ON a.attrelid = c.oid
          JOIN pg_catalog.pg_namespace n ON c.relnamespace = n.oid
          WHERE n.nspname = $1
            AND c.relname = $2
            AND a.attnum > 0
            AND NOT a.attisdropped
          ORDER BY a.attnum;
        `;

        const result = await this.pool.query(query, [schemaName, objectName]);

        return {
          columns: result.rows.map(row => ({
            name: row.name,
            type: row.type,
            nullable: !row.not_null,
            defaultValue: row.default_value,
            isPrimaryKey: row.is_primary_key,
            isForeignKey: row.is_foreign_key,
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
    return 'postgres';
  }
}

module.exports = PostgresDriver;
