local cosock = require "cosock"
local log = require "log"

local http_client = {}

local TIMEOUT = 10

local function parse_url(base_url)
  local scheme, host, port = tostring(base_url or ""):match("^(https?)://([^:/]+):?(%d*)")
  if not scheme or not host then
    return nil, "invalid_base_url"
  end

  if scheme ~= "http" then
    return nil, "unsupported_scheme"
  end

  return {
    host = host,
    port = tonumber(port) or 80,
  }
end

local function should_send_content_length(method, body)
  if body ~= "" then
    return true
  end

  local normalized_method = tostring(method or ""):upper()
  return normalized_method == "POST" or
    normalized_method == "PUT" or
    normalized_method == "PATCH" or
    normalized_method == "DELETE"
end

function http_client.request(method, base_url, path, body, headers)
  local target, parse_err = parse_url(base_url)
  if not target then
    return 0, "", parse_err
  end

  local sock, sock_err = cosock.socket.tcp()
  if not sock then
    return 0, "", "socket_create: " .. tostring(sock_err)
  end

  sock:settimeout(TIMEOUT)

  local ok, connect_err = sock:connect(target.host, target.port)
  if not ok then
    sock:close()
    return 0, "", "connect: " .. tostring(connect_err)
  end

  local body_str = body or ""
  local req_headers = headers or {}
  local lines = {
    string.format("%s %s HTTP/1.0", tostring(method or "GET"), path),
    string.format("Host: %s:%s", target.host, tostring(target.port)),
    "Connection: close",
  }

  for key, value in pairs(req_headers) do
    lines[#lines + 1] = tostring(key) .. ": " .. tostring(value)
  end

  if should_send_content_length(method, body_str) then
    lines[#lines + 1] = "Content-Length: " .. tostring(#body_str)
  end

  lines[#lines + 1] = ""
  lines[#lines + 1] = body_str

  local _, send_err = sock:send(table.concat(lines, "\r\n"))
  if send_err then
    sock:close()
    return 0, "", "send: " .. tostring(send_err)
  end

  local chunks = {}
  while true do
    local chunk, _, partial = sock:receive(4096)
    if chunk then
      chunks[#chunks + 1] = chunk
    else
      if partial and #partial > 0 then
        chunks[#chunks + 1] = partial
      end
      break
    end
  end

  sock:close()

  local full_response = table.concat(chunks)
  if full_response == "" then
    return 0, "", "empty_response"
  end

  local separator = full_response:find("\r\n\r\n", 1, true)
  if not separator then
    return 0, "", "no_header_separator"
  end

  local code = tonumber(full_response:match("^HTTP/%S+ (%d+)")) or 0
  local response_body = full_response:sub(separator + 4)
  if code == 0 then
    log.warn("Unparseable HTTP status line: " .. full_response:sub(1, 80))
  end

  return code, response_body, nil
end

return http_client
