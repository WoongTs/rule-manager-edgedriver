-- rule_manager.lua
-- Owns duplicate guard, Rule name conventions, create/delete orchestration.

local config = require "config"
local hash = require "util.hash"
local rules_guard = require "rules_guard"
local st_api = require "st_api"

local M = {}

local function stable_string(value)
  -- Minimal deterministic serialization for duplicate keys.
  -- Replace with a more robust JSON canonicalizer if needed.
  local t = type(value)
  if t == "nil" then return "null" end
  if t == "string" then return string.format("%q", value) end
  if t == "number" or t == "boolean" then return tostring(value) end
  if t ~= "table" then return string.format("%q", tostring(value)) end

  local keys = {}
  for k in pairs(value) do table.insert(keys, k) end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)

  local parts = {}
  for _, k in ipairs(keys) do
    table.insert(parts, stable_string(k) .. ":" .. stable_string(value[k]))
  end
  return "{" .. table.concat(parts, ",") .. "}"
end

local function short_label(label)
  label = tostring(label or "")
  if #label <= 32 then return label end
  return label:sub(1, 29) .. "..."
end

local function template_rule_label(template)
  local label = tostring(template and (template.rule_label or template.title or template.id) or "Rule")
  label = label:match("^%s*(.-)%s*$")
  if label == "" then return "Rule" end
  return label
end

local function input_key_order(template)
  local keys = {}

  if type(template and template.rule_name_input_keys) == "table" then
    for _, key in ipairs(template.rule_name_input_keys) do
      if tostring(key or "") ~= "" then
        keys[#keys + 1] = tostring(key)
      end
    end
  end

  if #keys == 0 and type(template and template.input_slots) == "table" then
    for _, slot in ipairs(template.input_slots) do
      local key = tostring(slot and (slot.key or slot.slot) or "")
      if key ~= "" then
        keys[#keys + 1] = key
      end
    end
  end

  return keys
end

local function input_labels(template, ctx)
  local labels = {}
  local inputs = ctx and ctx.inputs or {}

  for _, key in ipairs(input_key_order(template)) do
    local input = inputs[key]
    if input then
      local label = tostring(input.label or key)
      label = label:match("^%s*(.-)%s*$")
      if label ~= "" then
        labels[#labels + 1] = short_label(label)
      end
    end
  end

  if #labels == 0 then
    labels[#labels + 1] = "devices"
  end

  return labels
end

local function normalize_rules(payload)
  if type(payload) ~= "table" then
    return {}
  end

  if type(payload.items) == "table" then
    return payload.items
  end

  if type(payload.rules) == "table" then
    return payload.rules
  end

  return payload
end

local function extract_rule_id(rule)
  return tostring(rule and (rule.id or rule.ruleId) or "")
end

local function rule_hash(rule)
  local name = rule and rule.name or ""
  return name:match("#([0-9a-fA-F]+)")
end

local function record_from_rule(rule, template, duplicate_hash, inputs)
  return {
    rule_id = extract_rule_id(rule),
    name = rule.name,
    template_id = template.id,
    hash = duplicate_hash,
    inputs = inputs,
  }
end

local function contains_rule_id(payload, target_rule_id)
  target_rule_id = tostring(target_rule_id or "")
  if target_rule_id == "" then return false end

  for _, rule in ipairs(normalize_rules(payload)) do
    if extract_rule_id(rule) == target_rule_id then
      return true
    end
  end

  return false
end

local function reconcile_records(device, owned_rules)
  local records = M.load_records(device)
  local remote_by_hash = {}
  local changed = false

  for _, rule in ipairs(owned_rules or {}) do
    local h = rule_hash(rule)
    if h then
      remote_by_hash[h] = rule
    end
  end

  for h, record in pairs(records) do
    local remote = remote_by_hash[h]
    if not remote then
      records[h] = nil
      changed = true
    else
      local remote_id = extract_rule_id(remote)
      if record.rule_id ~= remote_id then
        record.rule_id = remote_id
        changed = true
      end
      if record.name ~= remote.name then
        record.name = remote.name
        changed = true
      end
      if record.hash ~= h then
        record.hash = h
        changed = true
      end
    end
  end

  if changed then
    M.save_records(device, records)
  end

  return records
end

local function assert_management_access(device, location_id)
  local ok, guard_err = rules_guard.assert_management_access(device, location_id)
  if ok then return true, nil end
  return false, guard_err
end

local function rule_generation(template)
  return tostring(template and template.rule_generation or "")
end

function M.compute_duplicate_hash(template, ctx)
  local key_material = template.duplicate_key(ctx)
  return hash.short_hash(stable_string(key_material))
end

function M.make_rule_name(template, ctx, duplicate_hash)
  return string.format(
    "%s %s: %s #%s",
    config.RULE_PREFIX,
    template_rule_label(template),
    table.concat(input_labels(template, ctx), ", "),
    duplicate_hash
  )
end

function M.load_records(device)
  return device:get_field(config.FIELD_KEYS.rule_records) or {}
end

function M.save_records(device, records)
  device:set_field(config.FIELD_KEYS.rule_records, records or {}, { persist = true })
end

function M.is_owned_rule(rule)
  local name = rule and rule.name or ""
  return name:sub(1, #config.RULE_PREFIX) == config.RULE_PREFIX
end

function M.rule_has_hash(rule, duplicate_hash)
  local name = rule and rule.name or ""
  return duplicate_hash and duplicate_hash ~= "" and name:find("#" .. duplicate_hash, 1, true) ~= nil
end

function M.find_remote_duplicate(rules_response, duplicate_hash)
  for _, rule in ipairs(normalize_rules(rules_response)) do
    if M.is_owned_rule(rule) and M.rule_has_hash(rule, duplicate_hash) then
      return rule
    end
  end
  return nil
end

function M.create_if_absent(device, template, ctx)
  -- ctx must include location_id, inputs, params.
  -- Returns: created_or_existing_rule, status, err
  -- status = "created" | "already_exists_local" | "already_exists_remote"
  assert(template, "template is required")
  assert(ctx and ctx.location_id, "ctx.location_id is required")

  if template.create_enabled == false then
    return nil, nil, {
      kind = "template",
      message = tostring(template.disabled_reason or "Template is not ready: verified Rule JSON required."),
    }
  end

  if rule_generation(template) ~= "single_rule" then
    return nil, nil, {
      kind = "template",
      message = "Unsupported template generation: " .. rule_generation(template),
    }
  end

  local duplicate_hash = M.compute_duplicate_hash(template, ctx)
  ctx.duplicate_hash = duplicate_hash
  ctx.rule_name = M.make_rule_name(template, ctx, duplicate_hash)

  local guard_ok, guard_err = assert_management_access(device, ctx.location_id)
  if not guard_ok then
    return nil, nil, guard_err
  end

  local rules, list_err = st_api.list_rules(device, ctx.location_id)
  if not rules then return nil, nil, list_err end

  local records = M.load_records(device)
  local local_record = records[duplicate_hash]
  local remote = M.find_remote_duplicate(rules, duplicate_hash)
  if remote then
    records[duplicate_hash] = record_from_rule(remote, template, duplicate_hash, ctx.inputs)
    M.save_records(device, records)
    return records[duplicate_hash], "already_exists_remote", nil
  end

  if local_record and contains_rule_id(rules, local_record.rule_id) then
    return local_record, "already_exists_local", nil
  elseif local_record then
    records[duplicate_hash] = nil
    M.save_records(device, records)
  end

  local build_ok, body_or_err = pcall(template.build_rule, ctx)
  if not build_ok then
    return nil, nil, { kind = "template", message = tostring(body_or_err) }
  end

  local body = body_or_err
  local created, create_err = st_api.create_rule(device, ctx.location_id, body)
  if not created then return nil, nil, create_err end

  local rule_id = extract_rule_id(created)
  if rule_id == "" then
    local lookup, lookup_err = st_api.list_rules(device, ctx.location_id)
    if not lookup then return nil, nil, lookup_err end
    local created_remote = M.find_remote_duplicate(lookup, duplicate_hash)
    if created_remote then
      created = created_remote
      rule_id = extract_rule_id(created_remote)
    end
  end

  records[duplicate_hash] = {
    rule_id = rule_id,
    name = created.name or ctx.rule_name,
    template_id = template.id,
    hash = duplicate_hash,
    inputs = ctx.inputs,
  }
  M.save_records(device, records)

  return records[duplicate_hash], "created", nil
end

function M.reconcile_owned_rules(device, location_id)
  local guard_ok, guard_err = assert_management_access(device, location_id)
  if not guard_ok then return nil, guard_err end

  local rules, err = st_api.list_rules(device, location_id)
  if not rules then return nil, err end

  local owned = {}
  for _, rule in ipairs(normalize_rules(rules)) do
    if M.is_owned_rule(rule) then
      table.insert(owned, rule)
    end
  end
  reconcile_records(device, owned)
  return owned, nil
end

function M.list_owned_rules(device, location_id)
  return M.reconcile_owned_rules(device, location_id)
end

function M.delete_owned_rule(device, location_id, rule)
  assert(rule, "rule is required")
  if not M.is_owned_rule(rule) then
    return false, { kind = "guard", message = "Refusing to delete a rule not owned by AEB RuleGen" }
  end

  local guard_ok, guard_err = assert_management_access(device, location_id)
  if not guard_ok then return false, guard_err end

  local rule_id = extract_rule_id(rule)
  local ok, err = st_api.delete_rule(device, location_id, rule_id)
  if not ok then return false, err end

  -- Remove from local records if hash can be inferred from name.
  local records = M.load_records(device)
  local h = rule_hash(rule)
  if h and records[h] then
    records[h] = nil
    M.save_records(device, records)
  end

  return true, nil
end

return M
