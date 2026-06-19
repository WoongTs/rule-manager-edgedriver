local log = require "log"

local config = require "config"

local discovery = {}

local DEVICE_NETWORK_ID = "rules-manager-aeb"
local DEVICE_LABEL = "Rules Manager [AEB]"

local create_requested = false

local function short_id(value)
  value = tostring(value or "")
  if #value <= 8 then return value end
  return value:sub(1, 8)
end

local function get_devices(driver)
  return driver:get_devices() or {}
end

local function find_existing_device(driver)
  for _, device in ipairs(get_devices(driver)) do
    if tostring(device.device_network_id or "") == DEVICE_NETWORK_ID then
      return device
    end
  end

  return nil
end

function discovery.create_device(driver)
  local success, err = pcall(function()
    driver:try_create_device({
      type = "LAN",
      device_network_id = DEVICE_NETWORK_ID,
      label = DEVICE_LABEL,
      profile = config.PROFILE_NAMES.main,
      manufacturer = "SmartThingsCommunity",
      model = DEVICE_LABEL,
      vendor_provided_label = DEVICE_LABEL,
    })
  end)

  if success then
    create_requested = true
    log.info(string.format("[rulegen][discovery] requested device create dni=%s profile=%s", DEVICE_NETWORK_ID, config.PROFILE_NAMES.main))
  else
    log.error("[rulegen][discovery] failed to request device create: " .. tostring(err))
  end

  return success
end

function discovery.handle_discovery(driver, opts, should_continue)
  if type(should_continue) == "function" and should_continue() == false then
    log.info("[rulegen][discovery] discovery cancelled before create")
    return
  end

  local existing = find_existing_device(driver)
  if existing ~= nil then
    log.info("[rulegen][discovery] device already exists dni=" .. short_id(existing.device_network_id))
    return
  end

  local devices = get_devices(driver)
  if #devices > 0 then
    log.info("[rulegen][discovery] existing device count=" .. tostring(#devices) .. "; skipping create")
    return
  end

  if create_requested then
    log.info("[rulegen][discovery] device create already requested; skipping duplicate request")
    return
  end

  discovery.create_device(driver)
end

return discovery
