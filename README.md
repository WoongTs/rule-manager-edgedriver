# Rule Manager Edge Driver

SmartThings Edge Driver source for creating, listing, and deleting SmartThings Rules from the SmartThings app UI through AEB/EdgeBridge.

The driver is meant for rule templates where users should not have to copy raw `deviceId`, `componentId`, or Rule JSON by hand. It presents selectable device/component candidates in the app, builds a guarded Rules API body, checks for duplicates, and only shows Rules owned by this driver for deletion.

## What It Includes

- A SmartThings Edge Driver package under `driver/`
- Custom capability definitions and presentations under `driver/capabilities/`
- Edge profiles for create/delete modes under `driver/profiles/`
- Lua source for UI handling, candidate indexing, Rule generation, duplicate guards, AEB forwarding, and Rule deletion

## Current Templates

| Template | Purpose |
| --- | --- |
| `knob_switch_level_to_light_level` | Uses one `switchLevel` controller value to control one target `switchLevel` device. |
| `switch_pair_on_off_sync` | Keeps two switch components synchronized in same or inverse mode, with optional delayed sync for cloud-latency edge cases. |

Generated Rule names use this format:

```text
[RG] <template label>: <device labels> #<hash>
```

## Requirements

- SmartThings CLI
- A SmartThings hub that can run Edge Drivers
- AEB/EdgeBridge running on the LAN with SmartThings API forwarding available
- SmartThings account/API permissions suitable for listing devices and managing Rules

This repository does not include PATs, OAuth tokens, account IDs, device IDs, location IDs, hub IDs, channel IDs, or local environment files.

## Build

From the repository root:

```powershell
smartthings edge:drivers:package --build-only rule-manager-edgedriver.zip .\driver
```

For an install to a private channel/hub, use the SmartThings CLI flow appropriate for your account and channel. Keep real channel IDs and hub IDs out of commits and issue logs.

## How It Works

The driver keeps SmartThings API calls behind this path:

```text
ui_controller.lua
  -> rule_manager.lua
    -> st_api.lua
      -> aeb_client.lua
```

Templates only define metadata and `build_rule(ctx)`. They do not call AEB or SmartThings APIs directly.

Delete mode is intentionally scoped: it lists and deletes Rules that match the driver-owned `[RG]` prefix/hash contract instead of exposing arbitrary account Rules.

## Status

The MVP template and the switch-pair sync template have been live-tested in the private development workspace. This public repository is the release-source export of the driver package, not the private development workspace or its verification logs.
