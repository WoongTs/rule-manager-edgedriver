-- templates/knob_switch_level_to_light_level.lua
-- MVP template: absolute switchLevel knob/controller -> switchLevel target.

local M = {
  id = "knob_switch_level_to_light_level",
  version = 1,
  title = "Knob Level to Target Level",
  rule_label = "Level Control",
  rule_name_input_keys = { "controller", "target" },
  category = "knob",
  complexity = "simple",
  rule_generation = "single_rule",
  ui_shape = "two_slot",
  create_enabled = true,
  intro = {
    en = "Use one controller level to set one target light level.",
    ko = "컨트롤러의 밝기 값을 따라 대상 조명의 밝기 값을 제어합니다.",
  },
}

M.input_slots = {
  {
    key = "controller",
    slot = "slot1",
    label = "Controller",
    status_label = "Controller",
    description = "Absolute knob or dimmer that emits switchLevel values",
    required_capabilities = { "switchLevel" },
    component_policy = "any_component_with_capability",
  },
  {
    key = "target",
    slot = "slot2",
    label = "Target",
    status_label = "Target",
    description = "Light or dimmer that receives the switchLevel setLevel command",
    required_capabilities = { "switchLevel" },
    component_policy = "any_component_with_capability",
  },
}

M.params = {}

M.selection_constraints = {
  {
    slots = { "controller", "target" },
    unit = "device_component",
    message = "Controller and target must be different.",
  },
}

local function trim(value)
  return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function input_device_operand(input)
  return {
    device = {
      devices = { input.device_id },
      component = trim(input.component_id) ~= "" and input.component_id or "main",
      capability = "switchLevel",
      attribute = "level",
    },
  }
end

function M.duplicate_key(ctx)
  return {
    template_id = M.id,
    template_version = M.version,
    location_id = ctx.location_id,
    controller = {
      device_id = ctx.inputs.controller.device_id,
      component_id = ctx.inputs.controller.component_id or "main",
    },
    target = {
      device_id = ctx.inputs.target.device_id,
      component_id = ctx.inputs.target.component_id or "main",
    },
    params = ctx.params or {},
  }
end

function M.build_rule(ctx)
  assert(ctx and type(ctx) == "table", "ctx table is required")
  assert(trim(ctx.rule_name) ~= "", "ctx.rule_name is required")
  assert(ctx.inputs and ctx.inputs.controller, "ctx.inputs.controller is required")
  assert(ctx.inputs and ctx.inputs.target, "ctx.inputs.target is required")

  local controller_component = trim(ctx.inputs.controller.component_id)
  local target_component = trim(ctx.inputs.target.component_id)
  local controller = {
    device_id = trim(ctx.inputs.controller.device_id),
    component_id = controller_component ~= "" and controller_component or "main",
  }
  local target = {
    device_id = trim(ctx.inputs.target.device_id),
    component_id = target_component ~= "" and target_component or "main",
  }

  assert(controller.device_id ~= "", "controller device_id is required")
  assert(target.device_id ~= "", "target device_id is required")

  return {
    name = ctx.rule_name,
    actions = {
      {
        ["if"] = {
          changes = {
            operand = input_device_operand(controller),
          },
          ["then"] = {
            {
              command = {
                devices = { target.device_id },
                commands = {
                  {
                    component = target.component_id,
                    capability = "switchLevel",
                    command = "setLevel",
                    arguments = {
                      input_device_operand(controller),
                    },
                  },
                },
              },
            },
          },
        },
      },
    },
  }
end

return M
