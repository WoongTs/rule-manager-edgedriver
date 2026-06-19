-- aeb_client.lua
-- AEB/EdgeBridge transport boundary.

local json = require "st.json"
local log = require "log"

local config = require "config"
local discovery = require "aeb_discovery"
local http_client = require "http_client"

local M = {}

local DEFAULT_SCHEME = "http://"

local function trim(value)
  return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function urlencode(value)
  return (tostring(value):gsub("([^%w%-%_%.%~])", function(char)
    return string.format("%%%02X", string.byte(char))
  end))
end

local function error_result(kind, message, detail, status)
  return {
    kind = kind,
    reason = kind,
    message = message or tostring(kind),
    detail = detail,
    status = status,
  }
end

local function json_decode(body)
  local ok, parsed = pcall(json.decode, body or "")
  if not ok or parsed == nil then
    return nil, error_result("json_parse", "Response JSON parse failed", body)
  end
  return parsed, nil
end

local function json_encode(value)
  local ok, encoded = pcall(json.encode, value)
  if not ok or not encoded then
    return nil, error_result("json_encode", "Request JSON encode failed", tostring(encoded))
  end
  return encoded, nil
end

local function persist_bridge(device, base_url, info)
  if not device or not base_url then return end

  device:set_field(config.FIELD_KEYS.bridge_base_url, base_url, { persist = true })

  info = info or {}
  local variant = info.variant or info.name or info.bridgeVersion or info.version
  if variant then
    device:set_field(config.FIELD_KEYS.bridge_variant, variant, { persist = true })
  end
end

local function clear_cached_bridge(device)
  if not device then return end
  device:set_field(config.FIELD_KEYS.bridge_base_url, nil, { persist = true })
  device:set_field(config.FIELD_KEYS.bridge_variant, nil, { persist = true })
end

function M.normalize_base_url(value, default_port)
  local url = trim(value)
  if url == "" then return nil end

  if not url:match("^https?://") then
    url = DEFAULT_SCHEME .. url
  end

  if default_port and not url:match("^https?://[^/]+:%d+") then
    url = url:gsub("^(https?://[^/]+)", "%1:" .. tostring(default_port), 1)
  end

  return url:gsub("/+$", "")
end

local function manual_base_url_from_device(device)
  local prefs = device.preferences or {}
  local manual = trim(prefs.bridgeIp)

  if manual ~= "" then
    local base_url = M.normalize_base_url(manual, config.DEFAULT_BRIDGE_PORT)
    persist_bridge(device, base_url)
    return base_url
  end

  return nil
end

local function cached_base_url_from_device(device)
  local cached = trim(device:get_field(config.FIELD_KEYS.bridge_base_url))
  if cached ~= "" then
    return M.normalize_base_url(cached)
  end

  return nil
end

local function base_url_from_device(device)
  return manual_base_url_from_device(device) or cached_base_url_from_device(device)
end

function M.discover_bridge(device)
  local discovered_url, discover_err, info = discovery.find_base_url()
  if discovered_url then
    persist_bridge(device, discovered_url, info)
    return discovered_url, nil, info
  end

  return nil, discover_err or error_result(
    "missing_aeb_base_url",
    "AEB bridge is not configured and mDNS discovery failed"
  )
end

function M.ensure_base_url(device, opts)
  opts = opts or {}
  local base_url = base_url_from_device(device)
  if base_url then return base_url, nil end

  if opts.discover then
    return M.discover_bridge(device)
  end

  return nil, error_result("missing_aeb_base_url", "AEB bridge is not configured")
end

function M.init(device)
  local base_url = base_url_from_device(device)
  if base_url then
    log.info("[rulegen][bridge] bridge configured " .. tostring(base_url))
  else
    log.info("[rulegen][bridge] bridge not configured; starting mDNS discovery")
    discovery.find_base_url_async(function(discovered_url, discover_err, info)
      if discovered_url then
        persist_bridge(device, discovered_url, info)
        log.info("[rulegen][bridge] bridge discovered " .. tostring(discovered_url))
      else
        log.warn("[rulegen][bridge] AEB mDNS discovery failed: " ..
          tostring(discover_err and (discover_err.reason or discover_err.message) or "unknown"))
      end
    end)
  end
end

function M.on_preferences_changed(device, old_preferences)
  local old_bridge_ip = trim(old_preferences and old_preferences.bridgeIp)
  local new_bridge_ip = trim(device.preferences and device.preferences.bridgeIp)

  if old_bridge_ip ~= new_bridge_ip then
    clear_cached_bridge(device)
  end

  M.init(device)
end

function M.ping(device)
  local base_url, base_err = M.ensure_base_url(device, { discover = true })
  if not base_url then
    return false, base_err
  end

  local code, response_body, request_err = http_client.request("POST", base_url, "/api/ping", "", nil)
  if code == 0 then
    return false, error_result("transport", "AEB ping transport failed", request_err)
  end

  if code < 200 or code >= 300 then
    return false, error_result("http_" .. tostring(code), "AEB ping HTTP " .. tostring(code), response_body, code)
  end

  local data = {}
  if response_body and response_body ~= "" then
    local parsed, parse_err = json_decode(response_body)
    if not parsed then return false, parse_err end
    data = parsed
  end

  device:set_field(config.FIELD_KEYS.bridge_variant, data.variant or data.name or "aeb", { persist = true })
  persist_bridge(device, base_url, data)
  return true, { variant = data.variant or data.name or "aeb", raw = data }
end

function M.forward_json(device, request)
  request = request or {}
  local base_url, base_err = M.ensure_base_url(device, { discover = true })
  if not base_url then
    return nil, base_err
  end

  local method = tostring(request.method or "GET"):upper()
  local target_url = trim(request.url)
  if target_url == "" then
    return nil, error_result("missing_target_url", "SmartThings target URL is required")
  end

  local body = nil
  local headers = request.headers
  if request.body ~= nil then
    local encoded, encode_err = json_encode(request.body)
    if not encoded then return nil, encode_err end
    body = encoded
    headers = headers or {}
    headers["Content-Type"] = "application/json"
  end

  local code, response_body, request_err = http_client.request(
    method,
    base_url,
    "/api/forward?url=" .. urlencode(target_url),
    body,
    headers
  )

  if code == 0 then
    return nil, error_result("transport", "AEB forward transport failed", request_err)
  end

  if request.accept_404 and code == 404 then
    return { not_found = true }, nil
  end

  if code < 200 or code >= 300 then
    return nil, error_result(
      "http_" .. tostring(code),
      "SmartThings API HTTP " .. tostring(code),
      response_body,
      code
    )
  end

  if response_body == nil or response_body == "" then
    return {}, nil
  end

  return json_decode(response_body)
end

return M
