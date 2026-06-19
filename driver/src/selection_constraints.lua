-- selection_constraints.lua
-- Template-scoped candidate conflict policies for create input slots.

local M = {}

local DEFAULT_MESSAGE = "Selected inputs conflict."

local function trim(value)
  return (tostring(value or "")):match("^%s*(.-)%s*$")
end

local function component_id(candidate)
  local value = trim(candidate and candidate.component_id)
  if value == "" then return "main" end
  return value
end

local function device_id(candidate)
  return trim(candidate and candidate.device_id)
end

local function same_device(left, right)
  return device_id(left) ~= "" and device_id(left) == device_id(right)
end

local function same_device_component(left, right)
  return same_device(left, right) and component_id(left) == component_id(right)
end

local function capability_set(candidate)
  local set = {}
  for _, cap_id in ipairs(candidate and candidate.capability_ids or {}) do
    local id = trim(cap_id)
    if id ~= "" then
      set[id] = true
    end
  end
  return set
end

local function capability_overlap(left, right)
  local left_set = capability_set(left)
  for _, cap_id in ipairs(right and right.capability_ids or {}) do
    if left_set[trim(cap_id)] then
      return true
    end
  end
  return false
end

local function conflicts_by_unit(unit, left, right)
  if unit == "device" then
    return same_device(left, right)
  end
  if unit == "device_component" then
    return same_device_component(left, right)
  end
  if unit == "device_component_capability" then
    return same_device_component(left, right) and capability_overlap(left, right)
  end
  return false
end

local function slot_name(slot)
  return tostring(slot and (slot.slot or slot.key) or "")
end

local function slot_key(slot)
  return tostring(slot and slot.key or slot_name(slot))
end

local function constraint_slots(constraint)
  if type(constraint and constraint.slots) ~= "table" then
    return {}
  end
  return constraint.slots
end

local function constraint_includes(constraint, input_key)
  input_key = tostring(input_key or "")
  for _, key in ipairs(constraint_slots(constraint)) do
    if tostring(key or "") == input_key then
      return true
    end
  end
  return false
end

function M.slot_name(slot)
  return slot_name(slot)
end

function M.slot_for_input_key(template, input_key)
  input_key = tostring(input_key or "")
  for _, slot in ipairs(template and template.input_slots or {}) do
    if slot_key(slot) == input_key then
      return slot
    end
  end
  return nil
end

function M.input_key_for_slot(template, slot_name_value)
  slot_name_value = tostring(slot_name_value or "")
  for _, slot in ipairs(template and template.input_slots or {}) do
    if slot_name(slot) == slot_name_value then
      return slot_key(slot)
    end
  end
  return nil
end

function M.selected_by_input_key(template, selected_by_slot)
  local selected = {}
  selected_by_slot = selected_by_slot or {}

  for _, slot in ipairs(template and template.input_slots or {}) do
    local key = slot_key(slot)
    local name = slot_name(slot)
    if key ~= "" and name ~= "" and selected_by_slot[name] then
      selected[key] = selected_by_slot[name]
    end
  end

  return selected
end

function M.find_conflict(template, input_key, candidate, selected_by_key)
  input_key = tostring(input_key or "")
  selected_by_key = selected_by_key or {}

  for _, constraint in ipairs(template and template.selection_constraints or {}) do
    if constraint_includes(constraint, input_key) then
      local unit = tostring(constraint.unit or "")
      for _, other_key in ipairs(constraint_slots(constraint)) do
        other_key = tostring(other_key or "")
        if other_key ~= "" and other_key ~= input_key then
          local other = selected_by_key[other_key]
          if other and conflicts_by_unit(unit, candidate, other) then
            return {
              constraint = constraint,
              input_key = input_key,
              other_key = other_key,
              unit = unit,
              message = trim(constraint.message) ~= "" and constraint.message or DEFAULT_MESSAGE,
            }
          end
        end
      end
    end
  end

  return nil
end

function M.filter_candidates(template, slot_schema, candidates, selected_by_key)
  local key = slot_key(slot_schema)
  local filtered = {}

  for _, candidate in ipairs(candidates or {}) do
    if not M.find_conflict(template, key, candidate, selected_by_key) then
      filtered[#filtered + 1] = candidate
    end
  end

  return filtered
end

return M
