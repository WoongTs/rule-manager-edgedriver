-- init.lua
-- Entry point for the AEB RuleGen Edge Driver skeleton.
--
-- This file should stay thin. Put behavior into modules:
-- - aeb_client.lua       : AEB/EdgeBridge transport
-- - st_api.lua           : SmartThings API wrappers
-- - device_index.lua     : capability/component candidate filtering
-- - ui_controller.lua    : detailView state and command handling
-- - rule_manager.lua     : duplicate guard + create/delete orchestration
-- - templates/*.lua      : Rule Builder template factories

local Driver = require "st.driver"
local capabilities = require "st.capabilities"
local log = require "log"

local config = require "config"
local discovery = require "discovery"
local ui = require "ui_controller"

local rulegen_create = capabilities[config.CAP_IDS.create]
local rulegen_create_two_slot_one_enum = capabilities[config.CAP_IDS.create_two_slot_one_enum]
local rulegen_create_two_slot_two_enum = capabilities[config.CAP_IDS.create_two_slot_two_enum]
local rulegen_delete = capabilities[config.CAP_IDS.delete]
local rulegen_template_intro = capabilities[config.CAP_IDS.template_intro]
local rulegen_status_summary = capabilities[config.CAP_IDS.status_summary]
local rulegen_status_panel = capabilities[config.CAP_IDS.status_panel]

local function short_id(value)
  value = tostring(value or "")
  if #value <= 8 then return value end
  return value:sub(1, 8)
end

local function device_init(driver, device)
  log.info(string.format("[rulegen][lifecycle] init dni=%s", short_id(device.device_network_id)))
  ui.init(driver, device)
end

local function device_added(driver, device)
  log.info(string.format("[rulegen][lifecycle] added dni=%s", short_id(device.device_network_id)))
  ui.init(driver, device)
end

local function device_removed(driver, device)
  log.info(string.format("[rulegen][lifecycle] removed dni=%s", short_id(device.device_network_id)))
  ui.on_removed(driver, device)
end

local function info_changed(driver, device, event, args)
  ui.on_info_changed(driver, device, event, args)
end

local function handle_refresh(driver, device, cmd)
  ui.handle_refresh(driver, device, cmd)
end

local function selection_arg(command)
  local args = command.args or {}
  return args.selectionKey or args[1]
end

local function handle_set_slot1(driver, device, cmd)
  ui.handle_slot_selected(driver, device, "slot1", selection_arg(cmd))
end

local function handle_set_slot2(driver, device, cmd)
  ui.handle_slot_selected(driver, device, "slot2", selection_arg(cmd))
end

local function handle_set_param1(driver, device, cmd)
  ui.handle_param_selected(driver, device, "param1", selection_arg(cmd))
end

local function handle_set_param2(driver, device, cmd)
  ui.handle_param_selected(driver, device, "param2", selection_arg(cmd))
end

local function handle_refresh_candidates(driver, device, cmd)
  ui.refresh_candidates(driver, device)
end

local function handle_create_rule(driver, device, cmd)
  ui.handle_create_rule(driver, device, cmd)
end

local function handle_set_rule(driver, device, cmd)
  ui.handle_rule_selected(driver, device, selection_arg(cmd))
end

local function handle_refresh_rules(driver, device, cmd)
  ui.refresh_owned_rules(driver, device)
end

local function handle_delete_rule(driver, device, cmd)
  ui.handle_delete_rule(driver, device, cmd)
end

local create_handlers = {
  [rulegen_create.commands.setSlotOne.NAME] = handle_set_slot1,
  [rulegen_create.commands.setSlotTwo.NAME] = handle_set_slot2,
  [rulegen_create.commands.refreshCandidates.NAME] = handle_refresh_candidates,
  [rulegen_create.commands.createRule.NAME] = handle_create_rule,
}

local create_two_slot_one_enum_handlers = {
  [rulegen_create_two_slot_one_enum.commands.setSlotOne.NAME] = handle_set_slot1,
  [rulegen_create_two_slot_one_enum.commands.setSlotTwo.NAME] = handle_set_slot2,
  [rulegen_create_two_slot_one_enum.commands.setParamOne.NAME] = handle_set_param1,
  [rulegen_create_two_slot_one_enum.commands.refreshCandidates.NAME] = handle_refresh_candidates,
  [rulegen_create_two_slot_one_enum.commands.createRule.NAME] = handle_create_rule,
}

local create_two_slot_two_enum_handlers = {
  [rulegen_create_two_slot_two_enum.commands.setSlotOne.NAME] = handle_set_slot1,
  [rulegen_create_two_slot_two_enum.commands.setSlotTwo.NAME] = handle_set_slot2,
  [rulegen_create_two_slot_two_enum.commands.setParamOne.NAME] = handle_set_param1,
  [rulegen_create_two_slot_two_enum.commands.setParamTwo.NAME] = handle_set_param2,
  [rulegen_create_two_slot_two_enum.commands.refreshCandidates.NAME] = handle_refresh_candidates,
  [rulegen_create_two_slot_two_enum.commands.createRule.NAME] = handle_create_rule,
}

local delete_handlers = {
  [rulegen_delete.commands.refreshRules.NAME] = handle_refresh_rules,
  [rulegen_delete.commands.deleteRule.NAME] = handle_delete_rule,
}

if rulegen_delete.commands.setSlotOne then
  delete_handlers[rulegen_delete.commands.setSlotOne.NAME] = handle_set_rule
end

local rulegen_driver = Driver("Rules Manager [AEB]", {
  supported_capabilities = {
    capabilities.refresh,
    capabilities.healthCheck,
    rulegen_create,
    rulegen_create_two_slot_one_enum,
    rulegen_create_two_slot_two_enum,
    rulegen_delete,
    rulegen_template_intro,
    rulegen_status_summary,
    rulegen_status_panel,
  },
  discovery = discovery.handle_discovery,
  lifecycle_handlers = {
    added = device_added,
    init = device_init,
    removed = device_removed,
    infoChanged = info_changed,
  },
  capability_handlers = {
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = handle_refresh,
    },
    [rulegen_create.ID] = create_handlers,
    [rulegen_create_two_slot_one_enum.ID] = create_two_slot_one_enum_handlers,
    [rulegen_create_two_slot_two_enum.ID] = create_two_slot_two_enum_handlers,
    [rulegen_delete.ID] = delete_handlers,
  },
})

log.info("[rulegen] Rules Manager [AEB] driver starting")
rulegen_driver:run()
