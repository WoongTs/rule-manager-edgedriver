-- template_registry.lua
-- Keeps the list of available Rule Builder-derived templates.

local config = require "config"

local M = {}

local templates = {
  require "templates.knob_switch_level_to_light_level",
  require "templates.switch_pair_on_off_sync",
}

local by_id = {}

local valid_constraint_units = {
  device = true,
  device_component = true,
  device_component_capability = true,
}

local function validate_template(t)
  assert(type(t.id) == "string" and t.id ~= "", "template.id is required")
  assert(type(t.version) == "number", "template.version is required")
  assert(type(t.title) == "string" and t.title ~= "", "template.title is required")
  assert(type(t.rule_generation) == "string" and t.rule_generation ~= "", "template.rule_generation is required")
  assert(type(t.ui_shape) == "string" and t.ui_shape ~= "", "template.ui_shape is required")
  assert(type(t.intro) == "table", "template.intro is required")
  assert(type(t.intro.en) == "string" and t.intro.en ~= "", "template.intro.en is required")
  assert(type(t.intro.ko) == "string" and t.intro.ko ~= "", "template.intro.ko is required")
  assert(type(t.input_slots) == "table" and #t.input_slots > 0, "template.input_slots is required")
  assert(type(t.build_rule) == "function", "template.build_rule is required")
  assert(type(t.duplicate_key) == "function", "template.duplicate_key is required")

  if t.create_enabled == nil then
    t.create_enabled = true
  end
  assert(type(t.create_enabled) == "boolean", "template.create_enabled must be boolean")
  if t.disabled_reason ~= nil then
    assert(type(t.disabled_reason) == "string", "template.disabled_reason must be a string")
  end

  local input_keys = {}
  for index, slot in ipairs(t.input_slots) do
    assert(type(slot) == "table", "template.input_slots[" .. index .. "] must be a table")
    assert(type(slot.key) == "string" and slot.key ~= "", "template.input_slots[" .. index .. "].key is required")
    assert(type(slot.slot) == "string" and slot.slot ~= "", "template.input_slots[" .. index .. "].slot is required")
    assert(type(slot.required_capabilities) == "table", "template.input_slots[" .. index .. "].required_capabilities is required")
    assert(not input_keys[slot.key], "duplicate input slot key: " .. slot.key)
    input_keys[slot.key] = true
  end

  t.params = t.params or {}
  assert(type(t.params) == "table", "template.params must be a table")
  for index, param in ipairs(t.params) do
    assert(type(param) == "table", "template.params[" .. index .. "] must be a table")
    assert(type(param.key) == "string" and param.key ~= "", "template.params[" .. index .. "].key is required")
    assert(type(param.slot) == "string" and param.slot ~= "", "template.params[" .. index .. "].slot is required")
    assert(type(param.type) == "string" and param.type ~= "", "template.params[" .. index .. "].type is required")
    if param.type == "enum" then
      assert(type(param.options) == "table" and #param.options > 0, "enum param options are required")
      local option_keys = {}
      local has_default = param.default == nil
      for option_index, option in ipairs(param.options) do
        assert(type(option) == "table", "enum param option must be a table")
        assert(type(option.key) == "string" and option.key ~= "", "enum param option key is required")
        assert(type(option.label) == "string" and option.label ~= "", "enum param option label is required")
        assert(not option_keys[option.key], "duplicate enum param option key: " .. option.key)
        option_keys[option.key] = true
        if option.key == param.default then
          has_default = true
        end
      end
      assert(has_default, "enum param default must match an option: " .. param.key)
    end
  end

  t.selection_constraints = t.selection_constraints or {}
  assert(type(t.selection_constraints) == "table", "template.selection_constraints must be a table")
  for index, constraint in ipairs(t.selection_constraints) do
    assert(type(constraint) == "table", "template.selection_constraints[" .. index .. "] must be a table")
    assert(type(constraint.slots) == "table" and #constraint.slots > 1, "selection constraint slots require at least two input keys")
    assert(valid_constraint_units[constraint.unit], "unsupported selection constraint unit: " .. tostring(constraint.unit))
    for _, key in ipairs(constraint.slots) do
      assert(input_keys[key], "selection constraint references unknown input key: " .. tostring(key))
    end
  end
end

for _, t in ipairs(templates) do
  validate_template(t)
  assert(not by_id[t.id], "duplicate template id: " .. t.id)
  by_id[t.id] = t
end

function M.get(template_id)
  return by_id[template_id]
end

function M.list()
  return templates
end

function M.default_id()
  return config.DEFAULT_TEMPLATE_ID
end

function M.param_values(template, selected_params)
  local values = {}
  selected_params = selected_params or {}

  for _, param in ipairs(template and template.params or {}) do
    local key = param.key
    if key and key ~= "" then
      if selected_params[key] ~= nil then
        values[key] = selected_params[key]
      else
        values[key] = param.default
      end
    end
  end

  return values
end

function M.param_for_slot(template, param_slot)
  param_slot = tostring(param_slot or "")
  for _, param in ipairs(template and template.params or {}) do
    if tostring(param.slot or "") == param_slot then
      return param
    end
  end
  return nil
end

function M.param_option_values(param)
  local values = {}
  for _, option in ipairs(param and param.options or {}) do
    values[#values + 1] = option.key
  end
  return values
end

function M.param_option_label(param, key)
  key = tostring(key or "")
  for _, option in ipairs(param and param.options or {}) do
    if option.key == key then
      return option.label
    end
  end
  return key
end

function M.intro_text(template, language)
  local intro = template and template.intro
  if type(intro) ~= "table" then return "" end

  language = tostring(language or "en")
  return tostring(intro[language] or intro.en or "")
end

function M.create_disabled_reason(template)
  if template and template.create_enabled ~= false then
    return nil
  end
  return tostring(template and template.disabled_reason or "Template is not ready: verified Rule JSON required.")
end

return M
