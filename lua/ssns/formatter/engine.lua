---@class FormatterState
---@field indent_level number Current indentation depth
---@field line_length number Characters on current line
---@field paren_depth number Parenthesis nesting depth
---@field in_subquery boolean Currently inside subquery
---@field clause_stack string[] Stack of active clauses
---@field last_token Token? Previous token processed
---@field current_clause string? Current clause being processed
---@field join_modifier string? Pending join modifier (INNER, LEFT, RIGHT, etc.)

---@class FormatterEngine
---Core formatting engine that processes token streams and applies transformation rules.
---Uses best-effort error handling - formats what it can, preserves the rest.
local Engine = {}

local Tokenizer = require('ssns.completion.tokenizer')
local Output = require('ssns.formatter.output')
local Stats = require('ssns.formatter.stats')
local Passes = require('ssns.formatter.passes')
local EngineCache = require('ssns.formatter.engine_cache')
local EngineConfig = require('ssns.formatter.engine_config')
local Helpers = require('ssns.formatter.engine_helpers')
local Processor = require('ssns.formatter.engine_processor')

-- High-resolution timer
local hrtime = vim.loop.hrtime

-- Export cache for external use
Engine.cache = EngineCache

-- Local aliases for frequently used helper functions
local create_state = Helpers.create_state
local is_join_modifier = Helpers.is_join_modifier
local is_major_clause = Helpers.is_major_clause

---Format SQL text with error recovery
---@param sql string The SQL text to format
---@param config FormatterConfig The formatter configuration
---@param opts? {dialect?: string, skip_stats?: boolean} Optional formatting options
---@return string formatted The formatted SQL text
function Engine.format(sql, config, opts)
  opts = opts or {}
  local skip_stats = opts.skip_stats

  -- Merge config with defaults to ensure all values are present
  config = EngineConfig.merge_with_defaults(config)

  -- Handle empty input
  if not sql or sql == "" then
    return sql
  end

  local total_start = hrtime()
  local tokenization_time = 0
  local processing_time = 0
  local output_time = 0
  local cache_hit = false
  local token_count = 0

  -- Try cache first
  local tokens = EngineCache.get(sql)
  if tokens then
    cache_hit = true
  else
    -- Safe tokenization - return original on failure
    local tokenize_start = hrtime()
    local err
    tokens, err = Helpers.safe_tokenize(Tokenizer, sql)
    tokenization_time = hrtime() - tokenize_start

    if not tokens or #tokens == 0 then
      -- Best effort: return original SQL if tokenization fails
      if not skip_stats then
        Stats.record({
          total_ns = hrtime() - total_start,
          input_size = #sql,
          cache_hit = false,
        })
      end
      return sql
    end

    -- Cache the tokens
    EngineCache.set(sql, tokens)
  end

  token_count = #tokens

  -- Create formatter state
  local state = create_state()

  -- Process tokens with error recovery
  local process_start = hrtime()
  local ok, processed_or_error = pcall(Processor.process_tokens, tokens, config, state)
  processing_time = hrtime() - process_start

  if not ok then
    -- Error during token processing - return original
    if not skip_stats then
      Stats.record({
        tokenization_ns = tokenization_time,
        processing_ns = processing_time,
        total_ns = hrtime() - total_start,
        input_size = #sql,
        token_count = token_count,
        cache_hit = cache_hit,
      })
    end
    return sql
  end

  -- Run all annotation passes in sequence
  -- Passes: clauses -> subqueries -> expressions -> structure -> spacing -> casing
  -- Each pass annotates tokens, building up context for output generation
  local passes_ok, passes_result = pcall(Passes.run_all, processed_or_error, config)
  if passes_ok then
    processed_or_error = passes_result
  end
  -- If passes fail, continue with unannotated tokens (graceful degradation)

  -- Generate output with error recovery
  local output_start = hrtime()
  local output_ok, output_or_error = pcall(Output.generate, processed_or_error, config)
  output_time = hrtime() - output_start

  -- Record stats
  if not skip_stats then
    Stats.record({
      tokenization_ns = tokenization_time,
      processing_ns = processing_time,
      output_ns = output_time,
      total_ns = hrtime() - total_start,
      input_size = #sql,
      token_count = token_count,
      cache_hit = cache_hit,
    })
  end

  if not output_ok then
    -- Error during output generation - return original
    return sql
  end

  return output_or_error
end

return Engine
