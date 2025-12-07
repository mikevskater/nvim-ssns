---@class RuleRegistry
---Rule registry and loader for the SQL formatter.
---Manages loading and applying formatting rules.
local RuleRegistry = {}

---@type table<string, FormatterRule>
local rules = {}

---Register a formatting rule
---@param name string Rule name
---@param rule FormatterRule Rule implementation
function RuleRegistry.register(name, rule)
  rules[name] = rule
end

---Get a registered rule
---@param name string Rule name
---@return FormatterRule|nil
function RuleRegistry.get(name)
  return rules[name]
end

---Get all registered rules
---@return table<string, FormatterRule>
function RuleRegistry.get_all()
  return rules
end

---Load all default rules
function RuleRegistry.load_defaults()
  -- Load base rule modules
  local indentation = require('ssns.formatter.rules.indentation')
  local spacing = require('ssns.formatter.rules.spacing')
  local keywords = require('ssns.formatter.rules.keywords')
  local alignment = require('ssns.formatter.rules.alignment')

  -- Load clause-specific rule modules
  local select_rules = require('ssns.formatter.rules.select')
  local from_rules = require('ssns.formatter.rules.from')
  local where_rules = require('ssns.formatter.rules.where')
  local groupby_rules = require('ssns.formatter.rules.groupby')
  local dml_rules = require('ssns.formatter.rules.dml')

  -- Register base rules
  RuleRegistry.register('indentation', indentation)
  RuleRegistry.register('spacing', spacing)
  RuleRegistry.register('keywords', keywords)
  RuleRegistry.register('alignment', alignment)

  -- Register clause-specific rules
  RuleRegistry.register('select', select_rules)
  RuleRegistry.register('from', from_rules)
  RuleRegistry.register('where', where_rules)
  RuleRegistry.register('groupby', groupby_rules)
  RuleRegistry.register('dml', dml_rules)
end

---Apply all rules to a token
---@param token Token
---@param context FormatterState
---@param config FormatterConfig
---@return Token
function RuleRegistry.apply_all(token, context, config)
  local result = token
  for _, rule in pairs(rules) do
    if rule.apply then
      result = rule.apply(result, context, config)
    end
  end
  return result
end

return RuleRegistry
