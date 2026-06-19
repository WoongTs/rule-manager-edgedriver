# Architecture

This guide describes the public module layout and runtime flow for Rule Manager Edge Driver. It is safe to export as `docs/architecture.md` in the public release repository.

## Purpose

Rule Manager lets a SmartThings Edge Driver create, list, and delete SmartThings Rules through AEB/EdgeBridge. The driver replaces manual Rule JSON editing with app-side selectors for devices, components, template parameters, and owned Rule deletion.

## Layer Map

```text
SmartThings app detailView
  -> ui_controller.lua
    -> profile_manager.lua
    -> template_registry.lua
    -> device_index.lua
    -> rule_manager.lua
      -> rules_guard.lua
      -> st_api.lua
        -> aeb_client.lua
          -> AEB / EdgeBridge on LAN
            -> SmartThings Cloud API
```

The main rule is simple: UI code handles app commands and state, templates build Rule JSON, and only the API layer talks to AEB/SmartThings.

## Module Responsibilities

### `driver/src/discovery.lua`

Handles SmartThings Edge discovery for the virtual Rule Manager device. This is the app-side device discovery path and is separate from EdgeBridge network discovery.

### `driver/src/aeb_discovery.lua`

Discovers AEB/EdgeBridge on the LAN through `_edgebridge._tcp.local` mDNS and TCP reachability checks. It is used when no manual Bridge Address or persisted base URL is available.

### `driver/src/ui_controller.lua`

Handles SmartThings detailView commands, preferences, selector state, intro/status rendering, candidate refresh, and create/delete button actions.

It does not create arbitrary runtime UI components. Instead, it emits values through predefined custom capabilities and asks `profile_manager.lua` to switch among predefined profiles.

### `driver/src/profile_manager.lua`

Maps mode, template, and `ui_shape` to a profile name.

Current create shapes:

| UI shape | Profile | Purpose |
| --- | --- | --- |
| `two_slot` | `rulegen-create-knob-switchlevel` | Two selector slots, no parameter dropdown |
| `two_slot_one_enum` | `rulegen-create-two-slot-one-enum` | Two selector slots plus one enum parameter |
| `two_slot_two_enum` | `rulegen-create-two-slot-two-enum` | Two selector slots plus two enum parameters |

Delete mode always uses `rulegen-delete`.

### `driver/src/device_index.lua`

Normalizes SmartThings devices API responses into selector candidates. It filters by component capability requirements from the active template and keeps UI labels separate from internal IDs.

Candidate shape:

```lua
{
  token = "slot1:001",
  label = "Device Label · main",
  selection_key = "Device Label · main",
  device_id = "<device-id>",
  component_id = "main",
  capability_ids = { "switch", "switchLevel" }
}
```

### `driver/src/template_registry.lua`

Loads active templates from `driver/src/templates/*.lua`, validates their metadata, and exposes template definitions to the UI and Rule manager.

### `driver/src/templates/*.lua`

Each template defines metadata, input slots, parameters, duplicate-key material, and `build_rule(ctx)`.

Templates do not call AEB, SmartThings APIs, or persistence directly.

### `driver/src/rule_manager.lua`

Owns the create/delete orchestration:

- validates selected inputs and params against the template,
- builds deterministic duplicate keys,
- creates `[RG] ... #<hash>` Rule names,
- checks local and remote duplicates,
- persists local Rule records,
- reconciles owned Rules for delete mode,
- blocks deletion of Rules not owned by this driver.

### `driver/src/rules_guard.lua`

Performs fail-closed Rules management access checks before create/delete. It uses read-only probes and returns short user-facing failure reasons when AEB/SmartThings access is not ready.

### `driver/src/st_api.lua`

Wraps SmartThings REST endpoints and hides pagination, location resolution, HTTP errors, and AEB transport details from upper layers.

Main endpoint categories:

```text
GET    /locations
GET    /devices
GET    /installedapps/me
GET    /installedapps?locationId=<location-id>
GET    /rules?locationId=<location-id>
POST   /rules?locationId=<location-id>
DELETE /rules/<rule-id>?locationId=<location-id>
```

### `driver/src/aeb_client.lua`

Calls AEB/EdgeBridge through `http_client.lua`, including `/api/ping` and `/api/forward?url=...`. It handles manual Bridge Address normalization, persisted base URL reuse, mDNS fallback discovery, and transport errors.

## Create Flow

```text
refresh candidates
  -> st_api.list_devices
  -> device_index.filter_by_slot
  -> ui_controller emits selector options

create rule
  -> ui_controller reads selected slots and params
  -> template_registry returns active template
  -> rule_manager builds context and duplicate hash
  -> rules_guard checks management access
  -> rule_manager checks local/remote duplicates
  -> template.build_rule(ctx)
  -> st_api.create_rule(locationId, body)
  -> rule_manager persists owned Rule record
  -> ui_controller emits success or failure status
```

## Delete Flow

```text
delete mode refresh
  -> resolve location
  -> rules_guard checks management access
  -> st_api.list_rules(locationId)
  -> rule_manager filters owned [RG] Rules
  -> delete_selector_adapter builds static selector options
  -> ui_controller emits delete options

delete selected Rule
  -> ui_controller reads selected Rule option
  -> rules_guard checks management access
  -> rule_manager verifies ownership
  -> st_api.delete_rule(locationId, ruleId)
  -> rule_manager removes/reconciles local record
  -> ui_controller emits success or failure status
```

## Rule Ownership

Generated Rule names follow this contract:

```text
[RG] <template label>: <device labels> #<hash>
```

Delete mode only displays Rules that match the driver-owned prefix/hash contract. It should not expose arbitrary account Rules for deletion.

## Persistence

The driver persists enough state to reconnect app selectors, bridge discovery, chosen params, and owned Rule records. Typical stored groups are:

```lua
{
  bridge = {
    base_url = "...",
    variant = "aeb"
  },
  ui = {
    mode = "create",
    template_id = "switch_pair_on_off_sync",
    requested_profile = "rulegen-create-two-slot-two-enum"
  },
  candidate_cache = {
    updated_at = 0,
    slots = {}
  },
  selected_inputs = {},
  selected_params = {},
  rule_records = {}
}
```

Do not persist access tokens, PATs, account identifiers, or raw private environment values in driver package files.

## Extension Points

The intended extension model is:

- add a new template under `driver/src/templates/`,
- register it in `driver/src/template_registry.lua`,
- use an existing `ui_shape` when possible,
- add a new predefined profile/capability only when the UI shape truly changes,
- keep API calls inside `rule_manager.lua -> st_api.lua -> aeb_client.lua`.

Workflow templates that create multiple Rules, require helper devices, or need rollback should be treated as a separate feature class rather than as simple single-Rule templates.
