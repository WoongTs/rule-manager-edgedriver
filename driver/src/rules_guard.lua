local st_api = require "st_api"

local rules_guard = {}

local function trim(value)
  return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function failure(reason, err, detail)
  return {
    kind = "rules_guard",
    reason = reason,
    message = rules_guard.failure_message(reason, err),
    detail = detail or tostring(err and err.detail or ""),
    source = err,
  }
end

local function item_count(data)
  if type(data) ~= "table" then
    return 0
  end

  if type(data.items) == "table" then
    return #data.items
  end

  return #data
end

local function tolerated_token_probe_error(err)
  local reason = tostring(err and (err.reason or err.kind) or "")
  return reason == "http_401" or reason == "http_403" or reason == "http_404"
end

function rules_guard.failure_message(reason, err)
  local normalized_reason = tostring(reason or "")
  local detail = tostring(err and err.detail or ""):lower()
  if normalized_reason == "installed_app_principal_probe_succeeded" or
    normalized_reason == "cli_capability_probe_failed" or
    normalized_reason == "cli_capability_probe_empty" or
    normalized_reason == "http_401" or
    normalized_reason == "http_403" or
    detail:find("cli", 1, true) then
    return "AEB CLI token required for Rules"
  end

  return "Rules access check failed"
end

function rules_guard.assert_management_access(device, location_id)
  if trim(location_id) == "" then
    return false, failure("missing_location_id", nil, "location_id is required")
  end

  local token_data, token_err = st_api.get_installed_app_token_info(device)
  if not token_data and token_err and not tolerated_token_probe_error(token_err) then
    return false, failure("token_principal_probe_failed", token_err)
  end

  local apps, apps_err = st_api.list_installed_apps(device, location_id)
  if not apps then
    local reason = tostring(apps_err and (apps_err.reason or apps_err.kind) or "cli_capability_probe_failed")
    return false, failure(reason == "" and "cli_capability_probe_failed" or reason, apps_err)
  end

  if item_count(apps) > 0 then
    return true, {
      reason = "cli_capability_probe",
      token_result = token_data,
      apps = apps,
    }
  end

  if token_data then
    return false, failure(
      "installed_app_principal_probe_succeeded",
      nil,
      "installed app token principal appears active without visible location installed apps"
    )
  end

  return false, failure(
    "cli_capability_probe_empty",
    nil,
    "installed apps probe returned no visible apps"
  )
end

return rules_guard
