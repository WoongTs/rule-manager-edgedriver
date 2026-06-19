# Development Guide

This guide explains how to build and extend the public driver package. It is safe to export as `docs/development.md` in the public release repository.

## Repository Layout

```text
driver/
  config.yaml
  capabilities/
  profiles/
  src/
```

The public release repository contains the driver package and public documentation. Private workspace process files, local verification logs, agent instructions, and local environment notes are not part of the public release.

## Build Locally

From the public repository root:

```powershell
smartthings edge:drivers:package --build-only rule-manager-edgedriver.zip .\driver
```

For an actual channel/hub install, use your own SmartThings CLI channel and hub workflow. Do not commit channel IDs, hub IDs, tokens, or local settings.

## Source Modules

| Module | Purpose |
| --- | --- |
| `src/init.lua` | Driver entry point and lifecycle/handler registration. |
| `src/discovery.lua` | SmartThings Edge discovery for the Rule Manager device. |
| `src/ui_controller.lua` | App command handling, selector state, profile switching, status rendering. |
| `src/profile_manager.lua` | Mode/template/UI-shape to profile mapping. |
| `src/device_index.lua` | Device/component candidate filtering. |
| `src/template_registry.lua` | Template loading and validation. |
| `src/templates/*.lua` | Template metadata and Rule JSON factories. |
| `src/rule_manager.lua` | Create/delete orchestration, duplicate guard, ownership filtering. |
| `src/rules_guard.lua` | Fail-closed Rules management access checks. |
| `src/st_api.lua` | SmartThings REST wrapper. |
| `src/aeb_client.lua` | AEB/EdgeBridge transport wrapper. |
| `src/http_client.lua` | HTTP helper used by AEB client. |
| `src/runtime_i18n.lua` | Runtime status text localization. |

## Development Principles

- Keep SmartThings API calls inside `rule_manager.lua -> st_api.lua -> aeb_client.lua`.
- Keep templates pure: metadata, duplicate-key material, and `build_rule(ctx)` only.
- Prefer existing UI shapes before adding new capabilities/profiles.
- Do not put unknown metadata fields inside Rules API request bodies.
- Fail closed before create/delete if Rules management access is unclear.
- Keep visible Rule names in the `[RG] <template label>: <device labels> #<hash>` format.

## Adding A Simple Template

1. Add `driver/src/templates/<template_id>.lua`.
2. Register it in `driver/src/template_registry.lua`.
3. Use an existing `ui_shape` when possible.
4. Define input slots, params, selection constraints, `build_rule(ctx)`, and `duplicate_key(ctx)`.
5. Add or update a verified Rule JSON fixture in the development workspace.
6. Run package build-only.
7. Test live create/delete before documenting live verification.

See `docs/templates.md` in the public release for detailed template metadata guidance.

## Adding A New UI Shape

Only add a new UI shape when an existing profile/capability cannot express the required controls.

Typical files:

```text
driver/capabilities/<capability-id>.json
driver/capabilities/<capability-id>.presentation.json
driver/capabilities/translations/<capability-id>.en.json
driver/capabilities/translations/<capability-id>.ko.json
driver/profiles/<profile-name>.yaml
driver/src/config.lua
driver/src/profile_manager.lua
driver/src/ui_controller.lua
```

SmartThings detailView controls are profile/capability-driven, so UI shape changes require package and presentation validation.

## Public Documentation

The public repository receives documentation through the private workspace export allowlist. Public docs should explain:

- how to install and use the driver,
- how modules are layered,
- how templates are authored,
- how to build and extend the package.

Private verification logs, personal device names, local environment notes, and agent workflow instructions should stay out of the public release.
