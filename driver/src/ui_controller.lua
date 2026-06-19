-- ui_controller.lua
-- Bridges SmartThings UI commands/preferences to the RuleGen core modules.

local log = require "log"
local capabilities = require "st.capabilities"
local config = require "config"
local aeb = require "aeb_client"
local st_api = require "st_api"
local device_index = require "device_index"
local selection_constraints = require "selection_constraints"
local delete_selector = require "delete_selector_adapter"
local profile_manager = require "profile_manager"
local registry = require "template_registry"
local rule_manager = require "rule_manager"
local i18n = require "runtime_i18n"

local M = {}

local NOT_SELECTED = delete_selector.NOT_SELECTED
local delete_cap = capabilities[config.CAP_IDS.delete]
local template_intro_cap = capabilities[config.CAP_IDS.template_intro]
local status_summary_cap = capabilities[config.CAP_IDS.status_summary]
local status_panel_cap = capabilities[config.CAP_IDS.status_panel]

local function trim(value)
  return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function short_text(value)
  value = tostring(value or "")
  if #value <= 256 then return value end
  return value:sub(1, 253) .. "..."
end

local function detail_text(value)
  value = tostring(value or "")
  if #value <= 1200 then return value end
  return value:sub(1, 1197) .. "..."
end

local function escape_html(value)
  return tostring(value or "")
    :gsub("&", "&amp;")
    :gsub("<", "&lt;")
    :gsub(">", "&gt;")
    :gsub('"', "&quot;")
    :gsub("'", "&#39;")
end

local function card_html(title, message)
  local escaped = escape_html(detail_text(message or ""))
    :gsub("\r\n", "\n")
    :gsub("\r", "\n")
    :gsub("\n", "<br/>")

  return "<div style='display:flex'><div style='line-height:1.2'>" ..
    "<div style='padding:4px;font-size:12px;line-height:1.5'>" ..
    "<b>" .. escape_html(title) .. "</b><br/><br/>" ..
    escaped ..
    "</div></div></div>"
end

local function status_html(device, message)
  return card_html(i18n.text(device, "RuleGen Status"), message)
end

local function template_intro_html(device, template)
  local escaped = escape_html(detail_text(registry.intro_text(template, i18n.language(device))))
    :gsub("\r\n", "\n")
    :gsub("\r", "\n")
    :gsub("\n", "<br/>")

  return "<div style='display:flex'><div style='line-height:1.2'>" ..
    "<div style='padding:4px;font-size:12px;line-height:1.5'>" ..
    escaped ..
    "</div></div></div>"
end

local function redact_detail(value)
  local text = short_text(value)
  if text == "" then return "" end

  text = text:gsub("[Bb]earer%s+[%w%._%-]+", "Bearer <redacted>")
  text = text:gsub('"[Aa]ccess[_-]?[Tt]oken"%s*:%s*"[^"]+"', '"accessToken":"<redacted>"')
  text = text:gsub('"[Rr]efresh[_-]?[Tt]oken"%s*:%s*"[^"]+"', '"refreshToken":"<redacted>"')
  text = text:gsub(
    "%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x",
    "<uuid>"
  )
  return text
end

local function status_from_error(device, prefix_key, err)
  local message = i18n.error_message(device, err)
  local detail = redact_detail(err and err.detail or "")
  if detail ~= "" then
    log.warn(string.format("[rulegen][ui] %s detail: %s", tostring(prefix_key), detail))
  end
  return i18n.text(device, "status_error", {
    prefix = i18n.text(device, prefix_key),
    message = message,
  })
end

local function emit_event(device, event)
  if event then
    device:emit_event(event)
  end
end

local function emit_component_event(device, component_id, event)
  if not event then return end
  if component_id == "main" then
    device:emit_event(event)
    return
  end

  local component = device.profile and device.profile.components and device.profile.components[component_id]
  if component then
    device:emit_component_event(component, event)
  else
    log.warn("[rulegen][ui] missing profile component: " .. tostring(component_id))
  end
end

local function debug_on(device)
  local prefs = device.preferences or {}
  return prefs.enableDebugLog == true
end

local function get_mode(device)
  local prefs = device.preferences or {}
  return prefs.rulegenMode or "create"
end

local function ready_status_key(device)
  if get_mode(device) == "delete" then
    return "Ready. Refresh the rule list to begin."
  end
  return "Ready. Refresh the device list to begin."
end

local function get_template_id(device)
  local prefs = device.preferences or {}
  local template_id = trim(prefs.templateId)
  if template_id == "" then
    return registry.default_id()
  end
  return template_id
end

local function set_status(device, message, params)
  message = i18n.text(device, message, params)
  device:set_field(config.FIELD_KEYS.last_status, message or "", { persist = true })
  log.info("[rulegen][ui] " .. tostring(message or ""))
  if status_summary_cap and status_summary_cap.statusText then
    emit_event(device, status_summary_cap.statusText(short_text(message or "")))
  end
  if status_panel_cap and status_panel_cap.result then
    emit_component_event(
      device,
      config.COMPONENT_IDS.status_panel,
      status_panel_cap.result({ html = status_html(device, message or "") })
    )
  end
end

local function slot_name(slot)
  return selection_constraints.slot_name(slot)
end

local function create_shape_for_template(template)
  local shape_name = tostring(template and template.ui_shape or "")
  return config.CREATE_UI_SHAPES[shape_name], shape_name
end

local function create_cap_for_template(template)
  local shape = create_shape_for_template(template)
  if not shape or not shape.capability_id then return nil end
  return capabilities[shape.capability_id]
end

local function create_slot_binding(create_cap, slot_name_value)
  if not create_cap then return nil end
  if slot_name_value == "slot1" then
    return {
      options = create_cap.slotOneOptions,
      selection = create_cap.slotOneSelection,
    }
  end
  if slot_name_value == "slot2" then
    return {
      options = create_cap.slotTwoOptions,
      selection = create_cap.slotTwoSelection,
    }
  end
  return nil
end

local function create_param_binding(create_cap, param_slot)
  if not create_cap then return nil end
  if param_slot == "param1" then
    return {
      options = create_cap.paramOneOptions,
      selection = create_cap.paramOneSelection,
    }
  end
  if param_slot == "param2" then
    return {
      options = create_cap.paramTwoOptions,
      selection = create_cap.paramTwoSelection,
    }
  end
  return nil
end

local function validate_create_shape(device, template)
  local slots = template and template.input_slots or {}
  local params = template and template.params or {}
  local shape, shape_name = create_shape_for_template(template)
  if not shape then
    return false, i18n.text(device, "unsupported_create_ui_shape", { shape = shape_name })
  end

  local create_cap = create_cap_for_template(template)
  if not create_cap then
    return false, i18n.text(device, "create_capability_unavailable", { shape = shape_name })
  end

  if #slots > (shape.max_slots or 0) then
    return false, i18n.text(device, "create_shape_requires_slots", {
      max_slots = shape.max_slots or 0,
    })
  end

  if #params > (shape.max_params or 0) then
    return false, i18n.text(device, "create_shape_requires_params", {
      max_params = shape.max_params or 0,
    })
  end

  for _, slot in ipairs(slots) do
    local name = slot_name(slot)
    local binding = create_slot_binding(create_cap, name)
    if not binding or not binding.options or not binding.selection then
      return false, i18n.text(device, "unsupported_create_slot", { slot = name })
    end
  end

  for _, param in ipairs(params) do
    local param_slot = tostring(param.slot or "")
    local binding = create_param_binding(create_cap, param_slot)
    if not binding or not binding.options or not binding.selection then
      return false, i18n.text(device, "unsupported_create_param", { param = param_slot })
    end
  end

  return true, nil
end

local function slot_status_label(template, slot_name_value)
  for _, slot in ipairs(template and template.input_slots or {}) do
    if slot_name(slot) == slot_name_value then
      return trim(slot.status_label or slot.label or slot.key or slot_name_value)
    end
  end
  return trim(slot_name_value)
end

local function selected_by_input_key(template, selected)
  return selection_constraints.selected_by_input_key(template, selected or {})
end

local function locations_from_payload(payload)
  if type(payload) ~= "table" then return {} end
  if type(payload.items) == "table" then return payload.items end
  if type(payload.locations) == "table" then return payload.locations end
  return payload
end

local function resolve_location_id(device, inputs)
  local location_id = trim(device:get_field(config.FIELD_KEYS.location_id))

  for _, input in pairs(inputs or {}) do
    local candidate_location = trim(input.location_id)
    if candidate_location ~= "" then
      if location_id ~= "" and location_id ~= candidate_location then
        return nil, i18n.text(device, "selected_devices_same_location")
      end
      location_id = candidate_location
    end
  end

  if location_id ~= "" then
    device:set_field(config.FIELD_KEYS.location_id, location_id, { persist = true })
    return location_id, nil
  end

  local locations, err = st_api.list_locations(device)
  if not locations then
    return nil, i18n.text(device, "location_lookup_failed", {
      detail = i18n.error_message(device, err),
    })
  end

  local items = locations_from_payload(locations)
  if #items == 1 then
    location_id = trim(items[1].locationId or items[1].id)
    if location_id ~= "" then
      device:set_field(config.FIELD_KEYS.location_id, location_id, { persist = true })
      return location_id, nil
    end
  end

  if #items > 1 then
    return nil, i18n.text(device, "multiple_locations")
  end

  return nil, i18n.text(device, "missing_location_id")
end

local function rebuild_create_cache(device, template, selected)
  local cache = device:get_field(config.FIELD_KEYS.candidate_cache) or {}
  local selected_by_key = selected_by_input_key(template, selected)
  if type(cache.slots) ~= "table" then return false end

  for _, slot in ipairs(template and template.input_slots or {}) do
    local name = slot_name(slot)
    local slot_cache = cache.slots[name]
    if slot_cache then
      local all_candidates = slot_cache.all_candidates or slot_cache.candidates or {}
      local candidates = selection_constraints.filter_candidates(template, slot, all_candidates, selected_by_key)
      slot_cache.candidates = candidates
      slot_cache.by_token = device_index.index_by_token(candidates)
      slot_cache.by_selection_key = device_index.index_by_selection_key(candidates)
      cache.slots[name] = slot_cache
    end
  end

  device:set_field(config.FIELD_KEYS.candidate_cache, cache, { persist = true })
  return true
end

local function option_values(items)
  local values = { NOT_SELECTED }
  for _, item in ipairs(items or {}) do
    values[#values + 1] = item.selection_key or item.label or item.name or item.token
  end
  return values
end

local function item_count(items)
  local count = 0
  for _, _ in ipairs(items or {}) do
    count = count + 1
  end
  return count
end

local function selected_value(selected, slot)
  local item = selected and selected[slot]
  return item and (item.selection_key or item.label or item.token) or NOT_SELECTED
end

local function emit_create_selection_value(device, template, slot_name_value, value)
  if not template then return end
  local create_cap = create_cap_for_template(template)
  local binding = create_slot_binding(create_cap, slot_name_value)
  if binding and binding.selection then
    emit_event(device, binding.selection(value))
  end
end

local function emit_create_param_value(device, template, param_slot, value)
  if not template then return end
  local create_cap = create_cap_for_template(template)
  local binding = create_param_binding(create_cap, param_slot)
  if binding and binding.selection then
    emit_event(device, binding.selection(value))
  end
end

local function first_candidate_selection(slot_cache)
  for _, candidate in ipairs(slot_cache and slot_cache.candidates or {}) do
    local value = candidate.selection_key or candidate.label or candidate.token
    if value and value ~= NOT_SELECTED then return value end
  end
  return nil
end

local function pulse_create_selection_if_unchanged(device, template, slot_name_value, previous_value, next_value)
  if next_value == NOT_SELECTED or previous_value ~= next_value then return end
  emit_create_selection_value(device, template, slot_name_value, NOT_SELECTED)
end

local function pulse_create_clear_if_unchanged(device, template, slot_name_value, previous_value, slot_cache)
  if previous_value ~= NOT_SELECTED then return end
  local alternate = first_candidate_selection(slot_cache)
  if alternate then
    emit_create_selection_value(device, template, slot_name_value, alternate)
  end
end

local function pulse_delete_selection_if_unchanged(device, previous_value, next_value)
  if not delete_cap or not delete_cap.slotOneSelection then return end
  if next_value == NOT_SELECTED or previous_value ~= next_value then return end
  emit_event(device, delete_cap.slotOneSelection(NOT_SELECTED))
end

local function pulse_delete_clear_if_unchanged(device, previous_value, cache)
  if not delete_cap or not delete_cap.slotOneSelection then return end
  if previous_value ~= NOT_SELECTED then return end
  local first_rule = cache and cache.rules and cache.rules[1]
  if first_rule and first_rule.selection_key then
    emit_event(device, delete_cap.slotOneSelection(first_rule.selection_key))
  end
end

local function param_option_values(param)
  return registry.param_option_values(param)
end

local function param_accepts_value(param, value)
  value = tostring(value or "")
  for _, option in ipairs(param and param.options or {}) do
    if option.key == value then
      return true
    end
  end
  return false
end

local function candidate_refresh_status(device, template, slot_counts)
  local lines = { i18n.text(device, "Device list refreshed.") }
  for _, slot in ipairs(template.input_slots or {}) do
    local name = slot_name(slot)
    local label = slot_status_label(template, name)
    lines[#lines + 1] = string.format("%s: %d", label, slot_counts[name] or 0)
  end
  return table.concat(lines, "\n")
end

local function emit_create_state(device, cache, selected, template)
  if not template then return end
  local create_cap = create_cap_for_template(template)
  if not create_cap then return end

  cache = cache or device:get_field(config.FIELD_KEYS.candidate_cache) or {}
  selected = selected or device:get_field(config.FIELD_KEYS.selected_inputs) or {}
  local selected_params = device:get_field(config.FIELD_KEYS.selected_params) or {}
  local param_values = registry.param_values(template, selected_params)
  local slots = cache.slots or {}

  for _, slot in ipairs(template.input_slots or {}) do
    local name = slot_name(slot)
    local binding = create_slot_binding(create_cap, name)
    local slot_cache = slots[name] or {}
    if binding and binding.options and binding.selection then
      emit_event(device, binding.options(option_values(slot_cache.candidates)))
      emit_event(device, binding.selection(selected_value(selected, name)))
    end
  end

  for _, param in ipairs(template.params or {}) do
    local binding = create_param_binding(create_cap, tostring(param.slot or ""))
    if binding and binding.options and binding.selection then
      emit_event(device, binding.options(param_option_values(param)))
      emit_event(device, binding.selection(tostring(param_values[param.key] or "")))
    end
  end
end

local function emit_delete_state(device, cache)
  if not delete_cap then return end

  cache = cache or device:get_field(config.FIELD_KEYS.owned_rule_cache) or {}
  local selected = device:get_field(config.FIELD_KEYS.selected_rule)
  local selection = selected and (selected.selection_key or selected.name) or NOT_SELECTED

  if delete_cap.slotOneOptions and delete_cap.slotOneSelection then
    emit_event(device, delete_cap.slotOneOptions(delete_selector.option_values(cache)))
    emit_event(device, delete_cap.slotOneSelection(selection))
  end
end

local function emit_template_intro_state(device, template)
  if not template_intro_cap or not template_intro_cap.result then return end
  if get_mode(device) == "delete" then return end
  if not template then return end

  emit_component_event(
    device,
    config.COMPONENT_IDS.template_intro,
    template_intro_cap.result({ html = template_intro_html(device, template) })
  )
end

local function emit_visible_state(device)
  if get_mode(device) == "delete" then
    emit_delete_state(device)
    return
  end

  local template = registry.get(get_template_id(device))
  if template then
    emit_template_intro_state(device, template)
    emit_create_state(device, nil, nil, template)
  end
end

local function clear_create_session(device)
  device:set_field(config.FIELD_KEYS.selected_inputs, nil, { persist = true })
  device:set_field(config.FIELD_KEYS.selected_params, nil, { persist = true })
  device:set_field(config.FIELD_KEYS.candidate_cache, nil, { persist = true })
end

local function bridge_error_message(device, err)
  local reason = tostring(err and (err.kind or err.reason) or err)
  if reason == "missing_aeb_base_url" or reason == "mdns_unavailable" or
    reason == "mdns_discover_failed" or reason == "no_reachable_aeb" then
    return i18n.text(device, "AEB bridge not found. Set Bridge Address as IP:port or check EdgeBridge.")
  end

  if reason == "transport" then
    return i18n.text(device, "AEB bridge unreachable. Check EdgeBridge.")
  end

  if reason:match("^http_") then
    return i18n.text(device, "smartthings_api_failed_through_aeb", { reason = reason })
  end

  return i18n.error_message(device, err)
end

function M.init(driver, device)
  -- Initialize bridge discovery and default UI state.
  aeb.init(device)
  local ok, desired = profile_manager.apply_current_profile(driver, device)
  emit_visible_state(device)
  if ok then
    set_status(device, ready_status_key(device))
  else
    set_status(device, "Profile update failed. Check driver package profiles.")
  end
end

function M.on_removed(driver, device)
  -- TODO: Decide whether to keep or delete generated Rules on driver removal.
  -- MVP default: do NOT auto-delete Rules on device removal. Deletion must be explicit.
  log.info("[rulegen][ui] device removed; generated Rules are not auto-deleted")
end

function M.on_info_changed(driver, device, event, args)
  -- React to bridge address, mode, template changes.
  -- Keep this light: refresh labels/status, don't create/delete automatically.
  local old_preferences = args and args.old_st_store and args.old_st_store.preferences or {}
  aeb.on_preferences_changed(device, old_preferences)
  local old_template_id = trim(old_preferences.templateId)
  if old_template_id == "" then
    old_template_id = registry.default_id()
  end
  if old_template_id ~= get_template_id(device) then
    clear_create_session(device)
  end
  local ok, desired = profile_manager.apply_current_profile(driver, device)
  emit_visible_state(device)
  if ok then
    set_status(device, ready_status_key(device))
  else
    set_status(device, "Preferences changed. Profile update failed.")
  end
end

function M.handle_refresh(driver, device, cmd)
  local mode = get_mode(device)
  if mode == "delete" then
    return M.refresh_owned_rules(driver, device)
  end
  return M.refresh_candidates(driver, device)
end

function M.refresh_candidates(driver, device)
  local template_id = get_template_id(device)
  local template = registry.get(template_id)
  if not template then
    return set_status(device, "unknown_template", { template_id = template_id })
  end

  local shape_ok, shape_err = validate_create_shape(device, template)
  if not shape_ok then
    return set_status(device, shape_err)
  end

  local devices_response, err = st_api.list_devices(device)
  if not devices_response then
    return set_status(device, bridge_error_message(device, err))
  end

  local cache = { template_id = template_id, slots = {} }
  local selected = device:get_field(config.FIELD_KEYS.selected_inputs) or {}
  local selected_by_key = selected_by_input_key(template, selected)
  for _, slot in ipairs(template.input_slots) do
    local all_candidates = device_index.candidates_for_slot(devices_response, slot)
    local candidates = selection_constraints.filter_candidates(template, slot, all_candidates, selected_by_key)

    cache.slots[slot_name(slot)] = {
      schema = slot,
      all_candidates = all_candidates,
      candidates = candidates,
      by_token = device_index.index_by_token(candidates),
      by_selection_key = device_index.index_by_selection_key(candidates),
    }

    if debug_on(device) then
      log.info(string.format(
        "[rulegen][devices] slot=%s required=%s candidates=%d",
        tostring(slot_name(slot)),
        table.concat(slot.required_capabilities or {}, "+"),
        #candidates
      ))
    end

  end

  device:set_field(config.FIELD_KEYS.candidate_cache, cache, { persist = true })
  emit_create_state(device, cache, selected, template)

  local slot_counts = {}
  local total_count = 0
  for _, slot in ipairs(template.input_slots or {}) do
    local name = slot_name(slot)
    local slot_cache = cache.slots[name] or {}
    slot_counts[name] = item_count(slot_cache.candidates)
    total_count = total_count + slot_counts[name]
  end

  if total_count == 0 then
    set_status(device, "No matching devices found.")
  else
    set_status(device, candidate_refresh_status(device, template, slot_counts))
  end
end

function M.handle_slot_selected(driver, device, slot_name, selection_key)
  -- Called by custom selector capability command handler.
  local cache = device:get_field(config.FIELD_KEYS.candidate_cache) or {}
  local slot_cache = cache.slots and cache.slots[slot_name]
  local template = registry.get(cache.template_id or get_template_id(device))
  local selected = device:get_field(config.FIELD_KEYS.selected_inputs) or {}
  local previous_value = selected_value(selected, slot_name)
  local input_key = template and selection_constraints.input_key_for_slot(template, slot_name) or nil

  if not template then
    return set_status(device, "Unknown template.")
  end

  if not input_key then
    return set_status(device, "invalid_selection_for", { slot = slot_name })
  end

  local shape_ok, shape_err = validate_create_shape(device, template)
  if not shape_ok then
    return set_status(device, shape_err)
  end

  if selection_key == NOT_SELECTED then
    selected[slot_name] = nil
    device:set_field(config.FIELD_KEYS.selected_inputs, selected, { persist = true })
    rebuild_create_cache(device, template, selected)
    pulse_create_clear_if_unchanged(device, template, slot_name, previous_value, slot_cache)
    emit_create_state(device, nil, selected, template)
    return set_status(device, "cleared_slot", { slot = slot_name })
  end

  local candidate = slot_cache and (
    slot_cache.by_selection_key and slot_cache.by_selection_key[selection_key] or
    slot_cache.by_token and slot_cache.by_token[selection_key]
  )
  if not candidate then
    return set_status(device, "invalid_selection_for", { slot = slot_name })
  end

  local conflict = selection_constraints.find_conflict(
    template,
    input_key or slot_name,
    candidate,
    selected_by_input_key(template, selected)
  )
  if conflict then
    return set_status(device, conflict.message)
  end

  selected[slot_name] = candidate
  local next_value = candidate.selection_key or candidate.label or candidate.token

  device:set_field(config.FIELD_KEYS.selected_inputs, selected, { persist = true })
  rebuild_create_cache(device, template, selected)
  pulse_create_selection_if_unchanged(device, template, slot_name, previous_value, next_value)
  emit_create_state(device, nil, selected, template)
  set_status(device, "selected_slot", { slot = slot_name, label = candidate.label })
end

function M.handle_param_selected(driver, device, param_slot, selection_key)
  local template_id = get_template_id(device)
  local template = registry.get(template_id)
  if not template then
    return set_status(device, "unknown_template", { template_id = template_id })
  end

  local shape_ok, shape_err = validate_create_shape(device, template)
  if not shape_ok then
    return set_status(device, shape_err)
  end

  local param = registry.param_for_slot(template, param_slot)
  if not param then
    return set_status(device, "invalid_param_selection_for", { param = param_slot })
  end

  selection_key = trim(selection_key)
  if not param_accepts_value(param, selection_key) then
    return set_status(device, "invalid_param_selection_for", { param = param_slot })
  end

  local selected_params = device:get_field(config.FIELD_KEYS.selected_params) or {}
  selected_params[param.key] = selection_key
  device:set_field(config.FIELD_KEYS.selected_params, selected_params, { persist = true })

  emit_create_param_value(device, template, param_slot, selection_key)
  emit_create_state(device, nil, nil, template)
  set_status(
    device,
    "selected_param",
    {
      label = trim(param.status_label or param.label or param.key),
      value = i18n.text(device, registry.param_option_label(param, selection_key)),
    }
  )
end

local function build_ctx_from_selection(device, template)
  local selected = device:get_field(config.FIELD_KEYS.selected_inputs) or {}
  local selected_params = device:get_field(config.FIELD_KEYS.selected_params) or {}
  local inputs = {}

  local shape_ok, shape_err = validate_create_shape(device, template)
  if not shape_ok then
    return nil, shape_err
  end

  for _, slot in ipairs(template.input_slots) do
    local slot_name = slot.slot or slot.key
    local c = selected[slot_name]
    if not c then
      return nil, i18n.text(device, "missing_selection", { slot = slot_name })
    end
    inputs[slot.key] = {
      device_id = c.device_id,
      component_id = c.component_id or "main",
      label = c.label,
      capability_ids = c.capability_ids,
      location_id = c.location_id,
    }
  end

  local selected_by_key = selected_by_input_key(template, selected)
  for _, slot in ipairs(template.input_slots) do
    local slot_name = slot.slot or slot.key
    local candidate = selected[slot_name]
    local conflict = selection_constraints.find_conflict(template, slot.key, candidate, selected_by_key)
    if conflict then
      return nil, conflict.message
    end
  end

  local location_id, location_err = resolve_location_id(device, inputs)
  if not location_id then
    return nil, location_err
  end

  return {
    location_id = location_id,
    template = template,
    inputs = inputs,
    params = registry.param_values(template, selected_params),
  }, nil
end

function M.handle_create_rule(driver, device, cmd)
  local template_id = get_template_id(device)
  local template = registry.get(template_id)
  if not template then
    return set_status(device, "unknown_template", { template_id = template_id })
  end

  local shape_ok, shape_err = validate_create_shape(device, template)
  if not shape_ok then
    return set_status(device, shape_err)
  end

  local disabled_reason = registry.create_disabled_reason(template)
  if disabled_reason then
    return set_status(device, disabled_reason)
  end

  local ctx, ctx_err = build_ctx_from_selection(device, template)
  if not ctx then
    return set_status(device, ctx_err)
  end

  local record, status, err = rule_manager.create_if_absent(device, template, ctx)
  if not record then
    return set_status(device, status_from_error(device, "rule_create_failed", err))
  end

  set_status(device, "rule_status", {
    status = i18n.text(device, tostring(status)),
    name = tostring(record.name),
  })
end

function M.refresh_owned_rules(driver, device)
  emit_delete_state(device)

  local location_id, location_err = resolve_location_id(device, {})
  if not location_id then
    return set_status(device, "cannot_list_rules", { detail = location_err })
  end

  local owned, err = rule_manager.reconcile_owned_rules(device, location_id)
  if not owned then
    return set_status(device, status_from_error(device, "rule_list_failed", err))
  end

  local cache = delete_selector.build_options(owned)
  device:set_field(config.FIELD_KEYS.owned_rule_cache, cache, { persist = true })
  emit_delete_state(device, cache)
  if cache.displayed_count == 1 then
    set_status(device, "owned_rules_refreshed_one", { name = tostring(cache.rules[1].name) })
  elseif cache.truncated then
    set_status(device, "owned_rules_refreshed_truncated", {
      displayed = cache.displayed_count,
      total = cache.total_count,
    })
  else
    set_status(device, "owned_rules_refreshed", { count = cache.displayed_count })
  end
end

function M.handle_rule_selected(driver, device, selection_key)
  local cache = device:get_field(config.FIELD_KEYS.owned_rule_cache) or {}
  local previous_rule = device:get_field(config.FIELD_KEYS.selected_rule)
  local previous_value = previous_rule and (previous_rule.selection_key or previous_rule.name) or NOT_SELECTED
  local selected, reason = delete_selector.resolve_selection(cache, selection_key)
  if reason == "not_selected" then
    device:set_field(config.FIELD_KEYS.selected_rule, nil, { persist = true })
    pulse_delete_clear_if_unchanged(device, previous_value, cache)
    emit_delete_state(device, cache)
    return set_status(device, "Cleared selected rule.")
  end

  if not selected then
    return set_status(device, "Invalid rule selection.")
  end

  device:set_field(config.FIELD_KEYS.selected_rule, selected.rule, { persist = true })
  pulse_delete_selection_if_unchanged(device, previous_value, selected.selection_key or selected.name)
  emit_delete_state(device, cache)
  set_status(device, "selected_rule", { name = tostring(selected.name) })
end

function M.handle_delete_rule(driver, device, cmd)
  local location_id, location_err = resolve_location_id(device, {})
  if not location_id then
    return set_status(device, "cannot_delete_rule", { detail = location_err })
  end

  local selected_rule = device:get_field(config.FIELD_KEYS.selected_rule)
  if not selected_rule then
    return set_status(device, "Select a rule to delete.")
  end

  local ok, err = rule_manager.delete_owned_rule(device, location_id, selected_rule)
  if not ok then
    return set_status(device, status_from_error(device, "rule_delete_failed", err))
  end

  local empty_cache = delete_selector.build_options({})
  device:set_field(config.FIELD_KEYS.selected_rule, nil, { persist = true })
  device:set_field(config.FIELD_KEYS.owned_rule_cache, empty_cache, { persist = true })
  emit_delete_state(device, empty_cache)

  local refreshed, refresh_err = rule_manager.reconcile_owned_rules(device, location_id)
  if not refreshed then
    set_status(device, status_from_error(device, "rule_deleted_refresh_failed", refresh_err))
    return
  end

  local cache = delete_selector.build_options(refreshed)
  device:set_field(config.FIELD_KEYS.owned_rule_cache, cache, { persist = true })
  emit_delete_state(device, cache)
  set_status(device, "rule_deleted_owned_rules_refreshed", { count = cache.displayed_count })
end

return M
