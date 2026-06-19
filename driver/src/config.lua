-- config.lua
-- Central constants for AEB RuleGen.
-- Keep real token/device/location values out of this file.

local M = {}

M.DEFAULT_BRIDGE_PORT = 8088
M.ST_API_BASE = "https://api.smartthings.com/v1"

M.RULE_PREFIX = "[RG]"
M.TEMPLATE_IDS = {
  knob_switch_level_to_light_level = "knob_switch_level_to_light_level",
  switch_pair_on_off_sync = "switch_pair_on_off_sync",
}
M.MVP_TEMPLATE_ID = M.TEMPLATE_IDS.knob_switch_level_to_light_level
M.DEFAULT_TEMPLATE_ID = M.TEMPLATE_IDS.switch_pair_on_off_sync

M.PROFILE_NAMES = {
  main = "rulegen-main",
  create_knob_switchlevel = "rulegen-create-knob-switchlevel",
  create_two_slot_one_enum = "rulegen-create-two-slot-one-enum",
  create_two_slot_two_enum = "rulegen-create-two-slot-two-enum",
  delete_rules = "rulegen-delete",
}

M.CAP_IDS = {
  create = "earthpilot19519.rulegenKnobLevelCreate",
  create_two_slot_one_enum = "earthpilot19519.rulegenTwoSlotOneEnumCreate",
  create_two_slot_two_enum = "earthpilot19519.rulegenTwoSlotTwoEnumCreate",
  delete = "earthpilot19519.rulegenRuleSelect",
  template_intro = "earthpilot19519.rulegenTemplateIntroCard",
  status_summary = "earthpilot19519.rulegenStatusCard",
  status_panel = "earthpilot19519.rulegenStatusPanel",
}

M.CREATE_UI_SHAPES = {
  two_slot = {
    profile_name = M.PROFILE_NAMES.create_knob_switchlevel,
    capability_id = M.CAP_IDS.create,
    max_slots = 2,
    max_params = 0,
  },
  two_slot_one_enum = {
    profile_name = M.PROFILE_NAMES.create_two_slot_one_enum,
    capability_id = M.CAP_IDS.create_two_slot_one_enum,
    max_slots = 2,
    max_params = 1,
  },
  two_slot_two_enum = {
    profile_name = M.PROFILE_NAMES.create_two_slot_two_enum,
    capability_id = M.CAP_IDS.create_two_slot_two_enum,
    max_slots = 2,
    max_params = 2,
  },
}

M.COMPONENT_IDS = {
  template_intro = "intro",
  status_panel = "status",
}

M.FIELD_KEYS = {
  bridge_base_url = "rulegen_bridge_base_url",
  bridge_variant = "rulegen_bridge_variant",
  candidate_cache = "rulegen_candidate_cache",
  location_id = "rulegen_location_id",
  owned_rule_cache = "rulegen_owned_rule_cache",
  selected_rule = "rulegen_selected_rule",
  selected_inputs = "rulegen_selected_inputs",
  selected_params = "rulegen_selected_params",
  rule_records = "rulegen_rule_records",
  last_status = "rulegen_last_status",
  requested_profile = "rulegen_requested_profile",
}

return M
