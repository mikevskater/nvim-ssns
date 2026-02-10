---ETL block template definitions for completion
---Built-in templates + user-defined templates loaded from JSON
---
---User templates location: stdpath('data')/nvim-ssns/etl_templates.json
---Format: array of { label, detail, description?, body: string[] }
---@class EtlSnippetData
local EtlSnippets = {}

---Cached user templates (loaded asynchronously at init)
---@type table[]?
EtlSnippets._user_cache = nil

---Whether async loading is in progress
EtlSnippets._loading = false

-- ============================================================================
-- Built-in templates
-- ============================================================================

---Core templates — always available
---@type table[]
EtlSnippets.core = {
  {
    label = "--newsql",
    detail = "New SQL block",
    description = "Basic SQL block with server and database connection.",
    body = {
      "--@block ${1:block_name}",
      "--@server ${2:server}",
      "--@database ${3:database}",
      "${0:SELECT * FROM }",
    },
  },
  {
    label = "--newlua",
    detail = "New Lua block",
    description = "Lua transformation block for scripting and data processing.",
    body = {
      "--@lua ${1:block_name}",
      "${0:-- Lua code here}",
    },
  },
  {
    label = "--newetl",
    detail = "New ETL block with full directives",
    description = "Complete ETL block with input, mode, and target for data movement.",
    body = {
      "--@block ${1:block_name}",
      "--@server ${2:server}",
      "--@database ${3:database}",
      "--@input ${4:source_block}",
      "--@mode ${5:select}",
      "--@target ${6:schema.table}",
      "${0:SELECT * FROM @input}",
    },
  },
}

---Sample templates — demonstrate patterns and features
---@type table[]
EtlSnippets.samples = {
  {
    label = "--newinsert",
    detail = "Insert pipeline block",
    description = "Reads from a source block and inserts rows into a target table.",
    body = {
      "--@block insert_${1:name}",
      "--@server ${2:server}",
      "--@database ${3:database}",
      "--@input ${4:source_block}",
      "--@mode insert",
      "--@target ${5:dbo.target_table}",
      "SELECT",
      "\t${0:col1, col2, col3}",
      "FROM @input",
    },
  },
  {
    label = "--newupsert",
    detail = "Upsert (insert or update) block",
    description = "Merges source data into target — inserts new rows, updates existing.",
    body = {
      "--@block upsert_${1:name}",
      "--@server ${2:server}",
      "--@database ${3:database}",
      "--@input ${4:source_block}",
      "--@mode upsert",
      "--@target ${5:dbo.target_table}",
      "SELECT",
      "\t${0:col1, col2, col3}",
      "FROM @input",
    },
  },
  {
    label = "--newpipeline",
    detail = "Two-block extract-load pipeline",
    description = "Linked pair: extract block queries source, load block inserts into target. Block names are linked — rename once, updates both.",
    body = {
      "--@block extract_${1:name}",
      "--@server ${2:source_server}",
      "--@database ${3:source_db}",
      "SELECT ${4:*}",
      "FROM ${5:dbo.source_table}",
      "",
      "--@block load_${1:name}",
      "--@server ${6:target_server}",
      "--@database ${7:target_db}",
      "--@input extract_${1:name}",
      "--@mode ${8:insert}",
      "--@target ${9:dbo.target_table}",
      "${0:SELECT * FROM @input}",
    },
  },
  {
    label = "--newlookup",
    detail = "Lua lookup/transform block",
    description = "Lua block that reads input data, applies a transformation, and outputs the result as a new data set.",
    body = {
      "--@lua transform_${1:name}",
      "--@input ${2:source_block}",
      "--@output data",
      "local rows = input",
      "local result = {}",
      "for _, row in ipairs(rows) do",
      "\t${0:table.insert(result, row)}",
      "end",
      "return result",
    },
  },
  {
    label = "--newconditional",
    detail = "Block with skip and error handling",
    description = "ETL block that skips if input is empty and continues the pipeline even on failure — useful for optional/non-critical steps.",
    body = {
      "--@block ${1:block_name}",
      "--@server ${2:server}",
      "--@database ${3:database}",
      "--@input ${4:source_block}",
      "--@skip_on_empty",
      "--@continue_on_error",
      "--@description ${5:Optional step - skips if no data}",
      "${0:SELECT * FROM @input}",
    },
  },
}

-- ============================================================================
-- User template loading (from JSON)
-- ============================================================================

---Get the path to the user ETL templates file
---@return string path
function EtlSnippets.get_user_file_path()
  return vim.fn.stdpath('data') .. '/nvim-ssns/etl_templates.json'
end

---Load user-defined ETL templates from JSON file asynchronously
---@param callback fun(templates: table[], error: string?)
function EtlSnippets.load_user_async(callback)
  local FileIO = require('nvim-ssns.async.file_io')
  local path = EtlSnippets.get_user_file_path()

  FileIO.exists_async(path, function(exists, _)
    if not exists then
      callback({}, nil)
      return
    end

    FileIO.read_json_async(path, function(data, err)
      if err then
        callback({}, err)
        return
      end

      -- Validate and normalize loaded templates
      local templates = {}
      if type(data) == "table" then
        for _, entry in ipairs(data) do
          if type(entry) == "table" and entry.label and entry.body then
            table.insert(templates, {
              label = entry.label,
              detail = entry.detail or "User ETL template",
              description = entry.description,
              body = entry.body, -- string[] — joined with \n at render time
            })
          end
        end
      end

      callback(templates, nil)
    end)
  end)
end

---Initialize user templates cache asynchronously
---Should be called at plugin startup
---@param callback fun(success: boolean, error: string?)?
function EtlSnippets.init_async(callback)
  if EtlSnippets._user_cache or EtlSnippets._loading then
    if callback then callback(true, nil) end
    return
  end

  EtlSnippets._loading = true

  EtlSnippets.load_user_async(function(templates, err)
    EtlSnippets._loading = false

    if err then
      EtlSnippets._user_cache = {}
      if callback then callback(false, err) end
      return
    end

    EtlSnippets._user_cache = templates or {}
    if callback then callback(true, nil) end
  end)
end

---Reload user templates (clears cache and reloads)
---@param callback fun(success: boolean, error: string?)?
function EtlSnippets.reload_async(callback)
  EtlSnippets._user_cache = nil
  EtlSnippets._loading = false
  EtlSnippets.init_async(callback)
end

-- ============================================================================
-- Public API
-- ============================================================================

---Get all templates (built-in core + samples + user)
---@return table[] templates Combined template list
function EtlSnippets.get_all()
  local result = {}
  vim.list_extend(result, EtlSnippets.core)
  vim.list_extend(result, EtlSnippets.samples)
  vim.list_extend(result, EtlSnippets._user_cache or {})
  return result
end

---Get only core templates (no samples, no user)
---@return table[] templates
function EtlSnippets.get_core()
  return vim.deepcopy(EtlSnippets.core)
end

---Write a sample user templates file with examples
---@param callback fun(success: boolean, error: string?)?
function EtlSnippets.create_sample_file(callback)
  local path = EtlSnippets.get_user_file_path()

  -- Don't overwrite existing file
  if vim.fn.filereadable(path) == 1 then
    if callback then
      callback(false, "File already exists: " .. path)
    end
    return
  end

  local sample = {
    {
      label = "--newaudit",
      detail = "Audit logging block",
      description = "Insert audit records into a logging table after processing.",
      body = {
        "--@block audit_${1:name}",
        "--@server ${2:server}",
        "--@database ${3:database}",
        "--@input ${4:source_block}",
        "--@mode insert",
        "--@target ${5:dbo.audit_log}",
        "--@continue_on_error",
        "--@description Audit log for ${1:name}",
        "SELECT",
        "\tGETDATE() AS logged_at,",
        "\t'${1:name}' AS operation,",
        "\t${0:*}",
        "FROM @input",
      },
    },
    {
      label = "--newarchive",
      detail = "Archive and purge block pair",
      description = "Two-block pattern: copy old rows to archive table, then delete from source.",
      body = {
        "--@block archive_${1:name}",
        "--@server ${2:server}",
        "--@database ${3:database}",
        "--@mode insert",
        "--@target ${4:dbo.archive_table}",
        "SELECT *",
        "FROM ${5:dbo.source_table}",
        "WHERE ${6:created_at} < DATEADD(DAY, -${7:90}, GETDATE())",
        "",
        "--@block purge_${1:name}",
        "--@server ${2:server}",
        "--@database ${3:database}",
        "--@input archive_${1:name}",
        "DELETE FROM ${5:dbo.source_table}",
        "WHERE ${6:created_at} < DATEADD(DAY, -${7:90}, GETDATE())",
      },
    },
  }

  local json = vim.json.encode(sample)
  -- Pretty-print with 2-space indent
  -- vim.json.encode produces compact JSON; we'll write it as-is
  local dir = vim.fn.fnamemodify(path, ':h')
  vim.fn.mkdir(dir, 'p')
  vim.fn.writefile({ json }, path)

  if callback then
    callback(true, nil)
  end
end

return EtlSnippets
