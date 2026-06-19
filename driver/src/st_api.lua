-- st_api.lua
-- SmartThings REST API wrappers.
--
-- All SmartThings API calls must go through this module, then through
-- aeb_client.lua. Do not call AEB or HTTP directly from UI/template modules.

local config = require "config"
local aeb = require "aeb_client"

local M = {}

local function urlencode(value)
  return (tostring(value):gsub("([^%w%-%_%.%~])", function(char)
    return string.format("%%%02X", string.byte(char))
  end))
end

local function endpoint(path)
  return config.ST_API_BASE .. path
end

local function request(device, method, path, body, opts)
  opts = opts or {}
  return aeb.forward_json(device, {
    method = method,
    url = endpoint(path),
    body = body,
    accept_404 = opts.accept_404 == true,
  })
end

function M.list_locations(device)
  -- GET /locations
  -- TODO: handle pagination if present.
  return request(device, "GET", "/locations", nil)
end

function M.list_devices(device)
  -- GET /devices
  -- TODO: handle pagination and room/location scoping if needed.
  return request(device, "GET", "/devices", nil)
end

function M.list_rules(device, location_id)
  -- GET /rules?locationId=<locationId>
  assert(location_id and location_id ~= "", "location_id is required")
  local path = "/rules?locationId=" .. urlencode(location_id)
  return request(device, "GET", path, nil)
end

function M.create_rule(device, location_id, rule_body)
  -- POST /rules?locationId=<locationId>
  assert(location_id and location_id ~= "", "location_id is required")
  assert(type(rule_body) == "table", "rule_body table is required")
  local path = "/rules?locationId=" .. urlencode(location_id)
  return request(device, "POST", path, rule_body)
end

function M.delete_rule(device, location_id, rule_id)
  -- DELETE /rules/<ruleId>?locationId=<locationId>
  assert(location_id and location_id ~= "", "location_id is required")
  assert(rule_id and rule_id ~= "", "rule_id is required")
  local path = "/rules/" .. urlencode(rule_id) .. "?locationId=" .. urlencode(location_id)
  return request(device, "DELETE", path, nil, { accept_404 = true })
end

function M.list_installed_apps(device, location_id)
  local path = "/installedapps"
  if location_id and location_id ~= "" then
    path = path .. "?locationId=" .. urlencode(location_id)
  end
  return request(device, "GET", path, nil)
end

function M.get_installed_app_token_info(device)
  return request(device, "GET", "/installedapps/me", nil)
end

return M
