-- device_index.lua
-- Converts SmartThings devices API responses into selector candidates.

local M = {}

local function list_items(response)
  if type(response) ~= "table" then return {} end
  if type(response.items) == "table" then return response.items end
  if type(response.devices) == "table" then return response.devices end
  return response
end

local function component_has_capability(component, capability_id)
  if type(component) ~= "table" or type(component.capabilities) ~= "table" then return false end
  for _, cap in ipairs(component.capabilities) do
    if cap.id == capability_id then
      return true
    end
  end
  return false
end

local function component_has_all(component, required_capabilities)
  for _, cap_id in ipairs(required_capabilities or {}) do
    if not component_has_capability(component, cap_id) then
      return false
    end
  end
  return true
end

local function device_label(device)
  return device.label or device.name or device.deviceId or "Unnamed device"
end

local function room_hint(device)
  -- SmartThings devices responses vary. Keep this defensive.
  if device.room and device.room.name then return device.room.name end
  if device.roomName then return device.roomName end
  return nil
end

local function make_label(device, component)
  local label = device_label(device)
  local comp = component.id or "main"
  local room = room_hint(device)
  if room and room ~= "" then
    return string.format("%s · %s · %s", room, label, comp)
  end
  return string.format("%s · %s", label, comp)
end

local function apply_selection_keys(candidates)
  local counts = {}
  local seen = {}

  for _, candidate in ipairs(candidates or {}) do
    local label = candidate.label or candidate.token or "Candidate"
    counts[label] = (counts[label] or 0) + 1
  end

  for _, candidate in ipairs(candidates or {}) do
    local label = candidate.label or candidate.token or "Candidate"
    if counts[label] and counts[label] > 1 then
      seen[label] = (seen[label] or 0) + 1
      candidate.selection_key = string.format("%s #%d", label, seen[label])
    else
      candidate.selection_key = label
    end
  end
end

local function same_device_component(candidate, other)
  if type(candidate) ~= "table" or type(other) ~= "table" then return false end
  return tostring(candidate.device_id or "") ~= "" and
    tostring(candidate.device_id or "") == tostring(other.device_id or "") and
    tostring(candidate.component_id or "main") == tostring(other.component_id or "main")
end

local function excluded(candidate, opts)
  opts = opts or {}
  local exclude = opts.exclude
  if type(exclude) ~= "table" then return false end

  if exclude.device_id or exclude.component_id then
    return same_device_component(candidate, exclude)
  end

  for _, item in ipairs(exclude) do
    if same_device_component(candidate, item) then
      return true
    end
  end

  return false
end

function M.candidates_for_slot(devices_response, slot_schema, opts)
  -- slot_schema.required_capabilities = { "switchLevel" }
  -- Returns array of selector candidates:
  -- {
  --   token = "slot1:001",
  --   label = "Living Room · Knob · main",
  --   selection_key = "Living Room · Knob · main",
  --   device_id = "...",
  --   component_id = "main",
  --   capability_ids = { ... }
  -- }
  local candidates = {}
  local devices = list_items(devices_response)
  local required = slot_schema.required_capabilities or {}
  local slot_name = slot_schema.slot or slot_schema.key or "slot"

  for _, device in ipairs(devices) do
    local components = device.components or {}
    for _, component in ipairs(components) do
      if component_has_all(component, required) then
        local capability_ids = {}
        for _, cap in ipairs(component.capabilities or {}) do
          table.insert(capability_ids, cap.id)
        end
        local n = #candidates + 1
        table.insert(candidates, {
          token = string.format("%s:%03d", slot_name, n),
          label = make_label(device, component),
          device_id = device.deviceId,
          component_id = component.id or "main",
          capability_ids = capability_ids,
          location_id = device.locationId,
        })

        if excluded(candidates[#candidates], opts) then
          table.remove(candidates)
        end
      end
    end
  end

  apply_selection_keys(candidates)
  return candidates
end

function M.index_by_token(candidates)
  local by_token = {}
  for _, c in ipairs(candidates or {}) do
    by_token[c.token] = c
  end
  return by_token
end

function M.index_by_selection_key(candidates)
  local by_selection_key = {}
  for _, c in ipairs(candidates or {}) do
    if c.selection_key then
      by_selection_key[c.selection_key] = c
    end
  end
  return by_selection_key
end

return M
