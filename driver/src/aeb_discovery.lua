local log = require "log"

local config = require "config"

local M = {}

local SERVICE_TYPE = "_edgebridge._tcp"
local DOMAIN = "local"
local INSTANCE_NAME = "EdgeBridge"

local has_mdns, mdns = pcall(require, "st.mdns")
local has_cosock, cosock = pcall(require, "cosock")

local function find_port_from_records(responses, instance_name)
  for _, answer in pairs(responses.answers or {}) do
    if answer.kind and answer.kind.SrvRecord and answer.name then
      if answer.name:find(instance_name, 1, true) then
        return answer.kind.SrvRecord.port
      end
    end
  end

  for _, additional in pairs(responses.additional or {}) do
    if additional.kind and additional.kind.SrvRecord and additional.name then
      if additional.name:find(instance_name, 1, true) then
        return additional.kind.SrvRecord.port
      end
    end
  end

  return nil
end

local function base_url(host, port)
  return "http://" .. tostring(host) .. ":" .. tostring(port or config.DEFAULT_BRIDGE_PORT)
end

local function is_tcp_reachable(host, port)
  if not has_cosock then
    return false, "cosock_unavailable"
  end

  local sock, sock_err = cosock.socket.tcp()
  if not sock then
    return false, "socket_create: " .. tostring(sock_err)
  end

  sock:settimeout(2)
  local ok, connect_err = sock:connect(host, tonumber(port))
  sock:close()
  if ok then
    return true, nil
  end

  return false, tostring(connect_err)
end

local function service_matches(service_info)
  local instance_name = service_info.name or ""
  local service_type = service_info.service_type or ""
  return service_type == SERVICE_TYPE and instance_name:find(INSTANCE_NAME, 1, true) ~= nil
end

function M.find_base_url()
  if not has_mdns then
    log.warn("[rulegen][bridge] AEB mDNS unavailable: st.mdns module not found")
    return nil, {
      kind = "mdns_unavailable",
      reason = "mdns_unavailable",
      message = "AEB mDNS discovery is unavailable",
    }
  end

  log.info("[rulegen][bridge] discovering AEB with mDNS service " .. SERVICE_TYPE .. "." .. DOMAIN)
  local responses, err = mdns.discover(SERVICE_TYPE, DOMAIN)
  if not responses then
    return nil, {
      kind = "mdns_discover_failed",
      reason = "mdns_discover_failed",
      message = "AEB mDNS discovery failed",
      detail = tostring(err),
    }
  end

  local candidates = {}
  for _, found in pairs(responses.found or {}) do
    local service_info = found.service_info or {}
    local host_info = found.host_info or {}
    if service_matches(service_info) and host_info.address then
      local instance_name = service_info.name or SERVICE_TYPE
      candidates[#candidates + 1] = {
        host = host_info.address,
        port = host_info.port or find_port_from_records(responses, instance_name) or config.DEFAULT_BRIDGE_PORT,
        instance_name = instance_name,
      }
    end
  end

  for _, candidate in ipairs(candidates) do
    local url = base_url(candidate.host, candidate.port)
    local ok, connect_err = is_tcp_reachable(candidate.host, candidate.port)
    if ok then
      log.info("[rulegen][bridge] AEB mDNS found " .. tostring(candidate.instance_name) .. " at " .. url)
      return url, nil, {
        host = candidate.host,
        port = candidate.port,
        instance_name = candidate.instance_name,
      }
    end
    log.warn("[rulegen][bridge] AEB mDNS candidate not reachable: " .. url ..
      " reason=" .. tostring(connect_err or "unknown"))
  end

  return nil, {
    kind = "no_reachable_aeb",
    reason = "no_reachable_aeb",
    message = "No reachable AEB bridge found",
  }
end

function M.find_base_url_async(callback)
  if has_cosock and cosock.spawn then
    cosock.spawn(function()
      local discovered_url, err, info = M.find_base_url()
      callback(discovered_url, err, info)
    end, "rulegen-aeb-mdns-discovery")
    return
  end

  local discovered_url, err, info = M.find_base_url()
  callback(discovered_url, err, info)
end

return M
