-- delete_selector_adapter.lua
-- Maps owned remote Rules to the fixed SmartThings list selector surface.

local M = {}

M.NOT_SELECTED = "Not selected"
M.MAX_RULE_OPTIONS = 20

local function shallow_copy(value)
  local copy = {}
  if type(value) ~= "table" then return copy end
  for k, v in pairs(value) do
    copy[k] = v
  end
  return copy
end

local function rule_id(rule)
  return rule and (rule.id or rule.ruleId) or nil
end

function M.selection_key(index)
  return string.format("Rule %d", index)
end

function M.build_options(owned_rules)
  local cache = {
    rules = {},
    by_token = {},
    by_selection_key = {},
    total_count = 0,
    displayed_count = 0,
    truncated = false,
  }

  for index, rule in ipairs(owned_rules or {}) do
    cache.total_count = cache.total_count + 1
    if index <= M.MAX_RULE_OPTIONS then
      local token = string.format("rule:%03d", index)
      local selection_key = M.selection_key(index)
      local rule_copy = shallow_copy(rule)
      rule_copy.selection_key = selection_key

      local item = {
        token = token,
        selection_key = selection_key,
        id = rule_id(rule_copy),
        name = rule_copy.name or token,
        rule = rule_copy,
      }

      cache.rules[#cache.rules + 1] = item
      cache.by_token[token] = item
      cache.by_selection_key[selection_key] = item
    end
  end

  cache.displayed_count = #cache.rules
  cache.truncated = cache.total_count > cache.displayed_count
  return cache
end

function M.option_values(cache)
  local values = { M.NOT_SELECTED }
  for _, item in ipairs((cache and cache.rules) or {}) do
    values[#values + 1] = item.selection_key
  end
  return values
end

function M.resolve_selection(cache, selection_key)
  if selection_key == M.NOT_SELECTED then
    return nil, "not_selected"
  end

  local selected = cache and cache.by_selection_key and cache.by_selection_key[selection_key] or nil
  if not selected and cache and cache.by_token then
    selected = cache.by_token[selection_key]
  end

  if not selected then
    return nil, "invalid_selection"
  end

  return selected, nil
end

return M
