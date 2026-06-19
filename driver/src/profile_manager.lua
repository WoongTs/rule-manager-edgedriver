-- profile_manager.lua
-- Maps RuleGen settings to predeclared SmartThings Edge profiles.

local log = require "log"
local config = require "config"
local registry = require "template_registry"

local M = {}

local function trim(value)
  return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function current_profile_name(device)
  local profile = device and device.profile
  if type(profile) == "table" then
    return trim(profile.name or profile.id)
  end
  return trim(profile)
end

function M.profile_for(mode, template_id)
  mode = trim(mode)
  template_id = trim(template_id)

  if mode == "delete" then
    return config.PROFILE_NAMES.delete_rules
  end

  if mode == "" or mode == "create" then
    local template = registry.get(template_id ~= "" and template_id or config.DEFAULT_TEMPLATE_ID)
    local shape = template and config.CREATE_UI_SHAPES[template.ui_shape]
    if shape and trim(shape.profile_name) ~= "" then
      return shape.profile_name
    end
  end

  return config.PROFILE_NAMES.main
end

function M.profile_for_device(device)
  local prefs = device and device.preferences or {}
  return M.profile_for(prefs.rulegenMode or "create", prefs.templateId or config.DEFAULT_TEMPLATE_ID)
end

function M.apply_current_profile(driver, device)
  local desired = M.profile_for_device(device)
  local current = current_profile_name(device)
  local last_requested = trim(device:get_field(config.FIELD_KEYS.requested_profile))

  if current == desired then
    device:set_field(config.FIELD_KEYS.requested_profile, desired, { persist = true })
    return true, desired, "already_current"
  end

  if current == "" and last_requested == desired then
    return true, desired, "already_requested"
  end

  local ok, result, err = pcall(function()
    return device:try_update_metadata({ profile = desired })
  end)

  if not ok then
    log.warn("[rulegen][profile] profile update failed: " .. tostring(result))
    return false, desired, tostring(result)
  end

  if result == false or (result == nil and err ~= nil) then
    log.warn("[rulegen][profile] profile update rejected: " .. tostring(err or "unknown"))
    return false, desired, tostring(err or "profile update rejected")
  end

  device:set_field(config.FIELD_KEYS.requested_profile, desired, { persist = true })
  log.info("[rulegen][profile] requested profile=" .. desired)
  return true, desired, "requested"
end

return M
