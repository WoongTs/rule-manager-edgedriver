# Template Authoring Guide

This guide explains how to add or modify Rule Builder templates for Rule Manager Edge Driver. It is safe to export as `docs/templates.md` in the public release repository.

## Active Templates

| Template | Purpose | UI shape |
| --- | --- | --- |
| `knob_switch_level_to_light_level` | Uses one `switchLevel` controller value to set one target `switchLevel` device. | `two_slot` |
| `switch_pair_on_off_sync` | Keeps two switch components synchronized in same or inverse mode. | `two_slot_two_enum` |

`switch_pair_on_off_sync` supports:

- `sync_mode = same | inverse`
- `sync_delay = immediate | delayed`

`delayed` inserts a short wait before target-state verification for cloud-latency edge cases.

## Files To Update

For a simple new template, update these files together:

```text
driver/src/templates/<template_id>.lua
driver/src/template_registry.lua
docs/09_template_authoring_guide.md
fixtures/rules.create.<template_id>.verified.json
```

If the template needs a new app UI shape, also add the matching custom capability, presentation, profile, translations, and profile-manager mapping.

## Template File Shape

Template files live under:

```text
driver/src/templates/<template_id>.lua
```

Minimal structure:

```lua
local M = {
  id = "example_template",
  version = 1,
  title = "Example Template",
  rule_label = "Example",
  rule_name_input_keys = { "source", "target" },
  category = "example",
  complexity = "simple",
  rule_generation = "single_rule",
  ui_shape = "two_slot",
  create_enabled = true,
  intro = {
    en = "Short explanation shown in create mode.",
    ko = "Create mode에 표시할 짧은 설명입니다."
  },

  input_slots = {},
  params = {},
  selection_constraints = {},

  build_rule = function(ctx)
    return {
      name = ctx.rule_name,
      actions = {}
    }
  end,

  duplicate_key = function(ctx)
    return {}
  end
}

return M
```

## Required Metadata

| Field | Purpose |
| --- | --- |
| `id` | Stable template ID. Use lowercase snake case. |
| `version` | Increment when duplicate semantics or Rule output changes. |
| `title` | Human-readable template title. |
| `rule_label` | Short label used inside generated Rule names. |
| `rule_generation` | Currently `single_rule` for active create flows. |
| `ui_shape` | Predefined app UI shape. |
| `create_enabled` | Set to `true` only after Rule output is verified. |
| `intro` | Short localized explanation for create mode. |
| `input_slots` | Device/component selector requirements. |
| `params` | Optional template parameters. |
| `build_rule(ctx)` | Returns SmartThings Rules API create body. |
| `duplicate_key(ctx)` | Returns deterministic duplicate-key material. |

## Input Slots

Each slot describes what kind of device/component can be selected.

```lua
{
  key = "controller",
  slot = "slot1",
  label = "Controller",
  status_label = "Controller",
  required_capabilities = { "switchLevel" },
  component_policy = "any_component_with_capability"
}
```

Supported component policies:

| Policy | Meaning |
| --- | --- |
| `main_only` | Only the `main` component is accepted. |
| `prefer_main` | Prefer `main` but allow other matching components. |
| `any_component_with_capability` | Any component with required capabilities is accepted. |
| `manual_component_allowed` | Allows explicit component selection when supported. |

## UI Shapes

SmartThings detailView controls are predefined through Edge profiles and custom capabilities. Templates select one shape; they do not create arbitrary UI at runtime.

| UI shape | Profile | Parameters |
| --- | --- | --- |
| `two_slot` | `rulegen-create-knob-switchlevel` | None |
| `two_slot_one_enum` | `rulegen-create-two-slot-one-enum` | `param1` enum |
| `two_slot_two_enum` | `rulegen-create-two-slot-two-enum` | `param1` enum, `param2` enum |

If a new template fits an existing shape, reuse it. Add a new shape only when the SmartThings app surface must change.

## Parameters

Enum parameter example:

```lua
params = {
  {
    key = "sync_mode",
    slot = "param1",
    label = "Mode",
    type = "enum",
    default = "same",
    options = {
      { key = "same", label = "Same state" },
      { key = "inverse", label = "Inverse state" }
    }
  }
}
```

`ctx.params` contains defaults merged with user selections.

## Selection Constraints

Selection constraints are template-specific. They are applied during candidate refresh and selection command validation.

```lua
selection_constraints = {
  {
    slots = { "source", "target" },
    unit = "device_component",
    message = "Source and target must be different."
  }
}
```

Supported units:

| Unit | Meaning |
| --- | --- |
| `device` | Blocks selecting the same device in both slots. |
| `device_component` | Blocks selecting the same device/component pair. |
| `device_component_capability` | Blocks overlap on the same device/component/capability. |

## Rule Names

`rule_manager.lua` creates names with this format:

```text
[RG] <rule_label>: <input labels> #<hash>
```

Use `rule_name_input_keys` to control which selected inputs appear in the name.

## `build_rule(ctx)`

`build_rule(ctx)` returns the SmartThings Rules API create body.

Context shape:

```lua
ctx = {
  location_id = "<location-id>",
  template = template,
  rule_name = "[RG] Example: Source, Target #abcd1234",
  duplicate_hash = "abcd1234",
  inputs = {
    source = {
      device_id = "<device-id>",
      component_id = "main",
      label = "Source Device"
    },
    target = {
      device_id = "<device-id>",
      component_id = "main",
      label = "Target Device"
    }
  },
  params = {}
}
```

Rules:

- Return only valid SmartThings Rules API fields.
- Do not add private metadata such as `_meta`, `templateId`, or `hash` to the API body.
- Do not call AEB or SmartThings APIs from the template.
- For no-argument commands such as `switch.on` and `switch.off`, omit `arguments`.

## `duplicate_key(ctx)`

The duplicate key should describe semantic uniqueness. Include at least:

```text
template id
template version
location id
selected device ids
selected component ids
selected params that change behavior
```

For symmetric templates, normalize input order. `switch_pair_on_off_sync` sorts the two endpoint keys so choosing A/B or B/A produces the same duplicate hash when the behavior is the same.

## Simple Template Or Workflow Template

Simple templates:

- create one SmartThings Rule,
- use one to three selector slots,
- use small enum/number/boolean params,
- do not need helper devices or rollback.

Workflow templates:

- create multiple Rules,
- require helper virtual devices,
- require user setup outside this driver,
- need rollback or partial-failure handling.

Workflow templates should be implemented as a separate feature class, not squeezed into the simple `single_rule` path.

## Pre-Release Checklist

Before enabling create:

```text
[ ] Template metadata validates at driver startup.
[ ] Candidate filtering returns only suitable devices/components.
[ ] Selection constraints reject unsafe duplicate selections.
[ ] build_rule(ctx) output matches a verified Rule JSON fixture.
[ ] duplicate_key(ctx) includes all behavior-changing inputs and params.
[ ] Rule name is readable and uses the [RG] prefix/hash contract.
[ ] SmartThings CLI package build-only passes.
[ ] Live create/delete is tested before claiming live verification.
```
