-- templates/switch_pair_on_off_sync.lua
-- Draft metadata template: two switches synchronized by on/off state.

local M = {
  id = "switch_pair_on_off_sync",
  version = 1,
  title = "Switch Pair Sync",
  rule_label = "Switch Pair Sync",
  rule_name_input_keys = { "switch_a", "switch_b" },
  category = "switch",
  complexity = "simple",
  rule_generation = "single_rule",
  ui_shape = "two_slot_two_enum",
  create_enabled = true,
  intro = {
    en = "Keep two switches in the same state or the opposite state.\nSome switches can trigger a loop bug. If that happens, choose Delayed for Sync delay to resolve it.",
    ko = "두 스위치를 같은 상태 또는 반대 상태로 자동 동기화합니다.\n일부 스위치에서는 루프 버그가 생길 수 있습니다. 그럴 경우 동기화 지연에서 '지연'을 선택하면 증상이 해결될 수 있습니다.",
  },
}

M.input_slots = {
  {
    key = "switch_a",
    slot = "slot1",
    label = "Input A",
    status_label = "Input A",
    description = "First switch component",
    required_capabilities = { "switch" },
    component_policy = "any_component_with_capability",
  },
  {
    key = "switch_b",
    slot = "slot2",
    label = "Input B",
    status_label = "Input B",
    description = "Second switch component",
    required_capabilities = { "switch" },
    component_policy = "any_component_with_capability",
  },
}

M.params = {
  {
    key = "sync_mode",
    slot = "param1",
    label = "Mode",
    status_label = "Mode",
    type = "enum",
    default = "same",
    options = {
      { key = "same", label = "Same state" },
      { key = "inverse", label = "Inverse state" },
    },
  },
  {
    key = "sync_delay",
    slot = "param2",
    label = "Sync delay",
    status_label = "Sync delay",
    type = "enum",
    default = "immediate",
    options = {
      { key = "immediate", label = "Immediate" },
      { key = "delayed", label = "Delayed" },
    },
  },
}

M.selection_constraints = {
  {
    slots = { "switch_a", "switch_b" },
    unit = "device_component",
    message = "Input A and Input B must be different.",
  },
}

local function trim(value)
  return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function component_id(input)
  local value = trim(input and input.component_id)
  if value == "" then return "main" end
  return value
end

local function endpoint(input, label)
  local result = {
    device_id = trim(input and input.device_id),
    component_id = component_id(input),
    label = trim(input and input.label),
  }

  assert(result.device_id ~= "", label .. " device_id is required")
  return result
end

local function sync_mode(params)
  local mode = trim(params and params.sync_mode)
  if mode == "inverse" then
    return "inverse"
  end
  return "same"
end

local function sync_delay(params)
  local delay = trim(params and params.sync_delay)
  if delay == "delayed" then
    return "delayed"
  end
  return "immediate"
end

local function endpoint_key(value)
  return value.device_id .. "\0" .. value.component_id
end

local function ordered_pair(left, right)
  if endpoint_key(right) < endpoint_key(left) then
    return right, left
  end
  return left, right
end

local function switch_operand(input, trigger)
  local operand = {
    device = {
      devices = { input.device_id },
      component = input.component_id,
      capability = "switch",
      attribute = "switch",
    },
  }

  if trigger then
    operand.device.trigger = trigger
  end

  return operand
end

local function command_action(target, state)
  return {
    command = {
      devices = { target.device_id },
      commands = {
        {
          component = target.component_id,
          capability = "switch",
          command = state,
        },
      },
    },
  }
end

local function sleep_action()
  return {
    sleep = {
      duration = {
        value = {
          integer = 1,
        },
        unit = "Second",
      },
    },
  }
end

local function sync_action(source, source_state, target, target_state, delay)
  local then_actions = {
    {
      ["if"] = {
        ["not"] = {
          equals = {
            left = switch_operand(target, "Never"),
            right = { string = target_state },
          },
        },
        ["then"] = {
          command_action(target, target_state),
        },
      },
    },
  }

  if delay == "delayed" then
    table.insert(then_actions, 1, sleep_action())
  end

  return {
    ["if"] = {
      changes = {
        equals = {
          left = switch_operand(source, "Always"),
          right = { string = source_state },
        },
      },
      ["then"] = then_actions,
    },
  }
end

function M.duplicate_key(ctx)
  assert(ctx and type(ctx) == "table", "ctx table is required")
  assert(ctx.inputs and ctx.inputs.switch_a, "ctx.inputs.switch_a is required")
  assert(ctx.inputs and ctx.inputs.switch_b, "ctx.inputs.switch_b is required")

  local switch_a = endpoint(ctx.inputs.switch_a, "switch_a")
  local switch_b = endpoint(ctx.inputs.switch_b, "switch_b")
  local first, second = ordered_pair(switch_a, switch_b)

  return {
    template_id = M.id,
    template_version = M.version,
    location_id = ctx.location_id,
    endpoints = {
      {
        device_id = first.device_id,
        component_id = first.component_id,
      },
      {
        device_id = second.device_id,
        component_id = second.component_id,
      },
    },
    params = {
      sync_mode = sync_mode(ctx.params),
      sync_delay = sync_delay(ctx.params),
    },
  }
end

function M.build_rule(ctx)
  assert(ctx and type(ctx) == "table", "ctx table is required")
  assert(trim(ctx.rule_name) ~= "", "ctx.rule_name is required")
  assert(ctx.inputs and ctx.inputs.switch_a, "ctx.inputs.switch_a is required")
  assert(ctx.inputs and ctx.inputs.switch_b, "ctx.inputs.switch_b is required")

  local switch_a = endpoint(ctx.inputs.switch_a, "switch_a")
  local switch_b = endpoint(ctx.inputs.switch_b, "switch_b")
  local mode = sync_mode(ctx.params)
  local delay = sync_delay(ctx.params)
  local on_target = mode == "inverse" and "off" or "on"
  local off_target = mode == "inverse" and "on" or "off"

  return {
    name = ctx.rule_name,
    actions = {
      sync_action(switch_a, "on", switch_b, on_target, delay),
      sync_action(switch_a, "off", switch_b, off_target, delay),
      sync_action(switch_b, "on", switch_a, on_target, delay),
      sync_action(switch_b, "off", switch_a, off_target, delay),
    },
  }
end

return M
