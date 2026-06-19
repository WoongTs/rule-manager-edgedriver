-- runtime_i18n.lua
-- Localizes Lua-generated status text. SmartThings app locale is not exposed to Edge Lua.

local M = {}

local DEFAULT_LANGUAGE = "ko"

local translations = {
  en = {
    ["RuleGen Status"] = "RuleGen Status",
    ["Intro"] = "Intro",
    ["Ready. Refresh the device list to begin."] = "Ready. Refresh the device list to begin.",
    ["Ready. Refresh the rule list to begin."] = "Ready. Refresh the rule list to begin.",
    ["Ready. Refresh candidates to begin."] = "Ready. Refresh the device list to begin.",
    ["Profile update failed. Check driver package profiles."] = "Profile update failed. Check driver package profiles.",
    ["Preferences changed. Profile update failed."] = "Preferences changed. Profile update failed.",
    ["Device list refreshed."] = "Device list refreshed.",
    ["Candidates refreshed."] = "Device list refreshed.",
    ["No matching devices found."] = "No matching devices found.",
    ["No candidates found."] = "No matching devices found.",
    ["Unknown template."] = "Unknown template.",
    ["Cleared selected rule."] = "Cleared selected rule.",
    ["Invalid rule selection."] = "Invalid rule selection.",
    ["Select a rule to delete."] = "Select a rule to delete.",
    ["AEB bridge not found. Set Bridge Address as IP:port or check EdgeBridge."] =
      "AEB bridge not found. Set Bridge Address as IP:port or check EdgeBridge.",
    ["AEB bridge unreachable. Check EdgeBridge."] = "AEB bridge unreachable. Check EdgeBridge.",
    ["AEB CLI token required for Rules"] = "AEB CLI token required for Rules",
    ["Rules access check failed"] = "Rules access check failed",
    ["Template is not ready: verified Rule JSON required."] =
      "Template is not ready: verified Rule JSON required.",
    ["Controller and target must be different."] = "Controller and target must be different.",
    ["Input A and Input B must be different."] = "Input A and Input B must be different.",
    ["Same state"] = "Same state",
    ["Inverse state"] = "Inverse state",
    ["Sync delay"] = "Sync delay",
    ["Immediate"] = "Immediate",
    ["Delayed"] = "Delayed",

    unknown_template = "Unknown template: %{template_id}",
    unsupported_create_ui_shape = "Unsupported create UI shape: %{shape}",
    create_capability_unavailable = "Create capability is not available for shape: %{shape}",
    create_shape_requires_slots =
      "Template requires a create UI shape with more than %{max_slots} slots.",
    create_shape_requires_params =
      "Template requires a create UI shape with more than %{max_params} params.",
    unsupported_create_slot = "Template uses unsupported create slot: %{slot}",
    unsupported_create_param = "Template uses unsupported create param: %{param}",
    selected_devices_same_location = "Selected devices must be in the same location.",
    location_lookup_failed = "Location lookup failed: %{detail}",
    multiple_locations = "Multiple locations found. Select devices with location metadata.",
    missing_location_id = "Missing location_id. Refresh the device list from AEB first.",
    smartthings_api_failed_through_aeb = "SmartThings API failed through AEB: %{reason}",
    invalid_selection_for = "Invalid selection for %{slot}",
    cleared_slot = "Cleared %{slot}",
    selected_slot = "Selected %{slot}: %{label}",
    invalid_param_selection_for = "Invalid param selection for %{param}",
    selected_param = "Selected %{label}: %{value}",
    missing_selection = "Missing selection: %{slot}",
    rule_create_failed = "Rule create failed",
    rule_list_failed = "Rule list failed",
    rule_delete_failed = "Rule delete failed",
    rule_deleted_refresh_failed = "Rule deleted. Refresh failed",
    status_error = "%{prefix}: %{message}",
    rule_status = "Rule %{status}: %{name}",
    cannot_list_rules = "Cannot list rules: %{detail}",
    owned_rules_refreshed_one = "Rule list refreshed: 1. Rule 1: %{name}",
    owned_rules_refreshed_truncated = "Rule list refreshed: %{displayed}/%{total} shown",
    owned_rules_refreshed = "Rule list refreshed: %{count}",
    selected_rule = "Selected rule: %{name}",
    cannot_delete_rule = "Cannot delete rule: %{detail}",
    rule_deleted_owned_rules_refreshed = "Rule deleted. Rule list refreshed: %{count}",
    created = "created",
    already_exists_local = "already_exists_local",
    already_exists_remote = "already_exists_remote",
  },

  ko = {
    ["RuleGen Status"] = "RuleGen Status",
    ["Intro"] = "소개",
    ["Ready. Refresh the device list to begin."] = "준비됨. 디바이스 목록을 새로고침해서 시작하세요.",
    ["Ready. Refresh the rule list to begin."] = "준비됨. Rule 목록을 새로고침해서 시작하세요.",
    ["Ready. Refresh candidates to begin."] = "준비됨. 디바이스 목록을 새로고침해서 시작하세요.",
    ["Profile update failed. Check driver package profiles."] =
      "Profile update 실패. driver package profiles를 확인하세요.",
    ["Preferences changed. Profile update failed."] =
      "Preferences가 변경되었지만 Profile update에 실패했습니다.",
    ["Device list refreshed."] = "디바이스 목록 새로고침 완료.",
    ["Candidates refreshed."] = "디바이스 목록 새로고침 완료.",
    ["No matching devices found."] = "조건에 맞는 디바이스를 찾지 못했습니다.",
    ["No candidates found."] = "조건에 맞는 디바이스를 찾지 못했습니다.",
    ["Unknown template."] = "알 수 없는 Template입니다.",
    ["Cleared selected rule."] = "선택한 Rule을 지웠습니다.",
    ["Invalid rule selection."] = "올바르지 않은 Rule 선택입니다.",
    ["Select a rule to delete."] = "삭제할 Rule을 선택하세요.",
    ["AEB bridge not found. Set Bridge Address as IP:port or check EdgeBridge."] =
      "AEB bridge를 찾지 못했습니다. Bridge Address를 IP:port로 설정하거나 EdgeBridge를 확인하세요.",
    ["AEB bridge unreachable. Check EdgeBridge."] =
      "AEB bridge에 연결할 수 없습니다. EdgeBridge를 확인하세요.",
    ["AEB CLI token required for Rules"] = "Rules 작업에는 AEB CLI token이 필요합니다.",
    ["Rules access check failed"] = "Rules access check에 실패했습니다.",
    ["Template is not ready: verified Rule JSON required."] =
      "Template이 아직 준비되지 않았습니다. verified Rule JSON이 필요합니다.",
    ["Controller and target must be different."] =
      "Controller와 target은 서로 달라야 합니다.",
    ["Input A and Input B must be different."] =
      "Input A와 Input B는 서로 달라야 합니다.",
    ["Same state"] = "같은 상태",
    ["Inverse state"] = "반대 상태",
    ["Sync delay"] = "동기화 지연",
    ["Immediate"] = "즉시",
    ["Delayed"] = "지연",

    unknown_template = "알 수 없는 Template: %{template_id}",
    unsupported_create_ui_shape = "지원하지 않는 create UI shape: %{shape}",
    create_capability_unavailable = "이 shape의 create capability를 사용할 수 없습니다: %{shape}",
    create_shape_requires_slots =
      "Template에 %{max_slots}개보다 많은 slot을 지원하는 create UI shape가 필요합니다.",
    create_shape_requires_params =
      "Template에 %{max_params}개보다 많은 param을 지원하는 create UI shape가 필요합니다.",
    unsupported_create_slot = "Template이 지원하지 않는 create slot을 사용합니다: %{slot}",
    unsupported_create_param = "Template이 지원하지 않는 create param을 사용합니다: %{param}",
    selected_devices_same_location = "선택한 devices는 같은 location에 있어야 합니다.",
    location_lookup_failed = "Location lookup 실패: %{detail}",
    multiple_locations = "여러 location이 발견되었습니다. location metadata가 있는 devices를 선택하세요.",
    missing_location_id = "location_id가 없습니다. 먼저 AEB에서 디바이스 목록을 새로고침하세요.",
    smartthings_api_failed_through_aeb = "AEB를 통한 SmartThings API 호출 실패: %{reason}",
    invalid_selection_for = "%{slot} 선택이 올바르지 않습니다.",
    cleared_slot = "%{slot} 선택을 지웠습니다.",
    selected_slot = "%{slot} 선택: %{label}",
    invalid_param_selection_for = "%{param} param 선택이 올바르지 않습니다.",
    selected_param = "%{label} 선택: %{value}",
    missing_selection = "선택이 필요합니다: %{slot}",
    rule_create_failed = "Rule create 실패",
    rule_list_failed = "Rule list 실패",
    rule_delete_failed = "Rule delete 실패",
    rule_deleted_refresh_failed = "Rule 삭제 완료. Refresh 실패",
    status_error = "%{prefix}: %{message}",
    rule_status = "Rule %{status}: %{name}",
    cannot_list_rules = "Rules를 표시할 수 없습니다: %{detail}",
    owned_rules_refreshed_one = "Rule 목록 새로고침 완료: 1. Rule 1: %{name}",
    owned_rules_refreshed_truncated = "Rule 목록 새로고침 완료: %{displayed}/%{total} 표시",
    owned_rules_refreshed = "Rule 목록 새로고침 완료: %{count}",
    selected_rule = "선택한 Rule: %{name}",
    cannot_delete_rule = "Rule을 삭제할 수 없습니다: %{detail}",
    rule_deleted_owned_rules_refreshed = "Rule 삭제 완료. Rule 목록 새로고침 완료: %{count}",
    created = "created",
    already_exists_local = "already_exists_local",
    already_exists_remote = "already_exists_remote",
  },
}

local function trim(value)
  return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function interpolate(template, params)
  if type(params) ~= "table" then return template end
  return (template:gsub("%%{([%w_]+)}", function(key)
    local value = params[key]
    if value == nil then return "" end
    return tostring(value)
  end))
end

function M.language(device)
  local prefs = device and device.preferences or {}
  local language = trim(prefs.statusLanguage)
  if language == "en" then return "en" end
  if language == "ko" then return "ko" end
  return DEFAULT_LANGUAGE
end

function M.text(device, key, params)
  key = tostring(key or "")
  local language = M.language(device)
  local table_for_language = translations[language] or translations[DEFAULT_LANGUAGE]
  local template = table_for_language[key] or translations[DEFAULT_LANGUAGE][key] or key
  return interpolate(template, params)
end

function M.error_message(device, err)
  local message = tostring(err and err.message or err)
  return M.text(device, message)
end

return M
