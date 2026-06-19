# Usage Guide

This guide explains how to install and use Rule Manager Edge Driver from the public SmartThings Edge channel. It is safe to export as `docs/usage.md` in the public release repository.

## What You Need

- A SmartThings account and hub that supports Edge Drivers.
- AEB/EdgeBridge running on the same LAN as the hub.
- SmartThings API access through AEB/EdgeBridge for device listing and Rules management.
- The Rule Manager Edge Driver installed on your hub.

The driver does not store PATs, OAuth tokens, account IDs, location IDs, hub IDs, or device IDs in the repository.

## Install From Channel

Join the public SmartThings Edge channel:

```text
https://bestow-regional.api.smartthings.com/invite/wvjJz49AaNjk
```

Invite code:

```text
wvjJz49AaNjk
```

After accepting the invitation:

1. Enroll your hub in the channel.
2. Install the Rule Manager driver from the channel page.
3. Add the Rule Manager device from SmartThings app discovery if it is not already present.
4. Configure AEB/EdgeBridge before trying candidate refresh or Rule create/delete.

## AEB/EdgeBridge Setup

The driver calls SmartThings Cloud APIs through AEB/EdgeBridge on your LAN.

In the Rule Manager device settings:

- Leave `Bridge Address` empty to use `_edgebridge._tcp` mDNS discovery when available.
- Or set `Bridge Address` manually as `IP:port`, for example `192.168.x.xx:8088`.

The driver uses AEB/EdgeBridge to:

- list locations,
- list devices and components,
- list Rules,
- create Rules,
- delete driver-owned Rules.

If AEB/EdgeBridge is missing or lacks Rules access, create/delete commands fail closed and show a short status message in the app.

## Create A Rule

1. Open the Rule Manager device in the SmartThings app.
2. Set mode to create.
3. Select a template.
4. Tap refresh candidates.
5. Select the required devices/components.
6. Select any template parameters.
7. Tap create Rule.
8. Read the status panel for success, duplicate, or failure details.

Generated Rules use this name format:

```text
[RG] <template label>: <device labels> #<hash>
```

The hash is used for duplicate detection and safe delete filtering.

## Delete A Rule

1. Switch the Rule Manager device to delete mode.
2. Refresh the Rule list.
3. Select one of the listed Rules.
4. Tap delete Rule.

Delete mode only lists Rules that match this driver's `[RG]` ownership contract. It is not intended to expose or delete arbitrary SmartThings Rules in your account.

## Current Templates

### Level Control

Template ID:

```text
knob_switch_level_to_light_level
```

Uses one `switchLevel` controller value to set one target `switchLevel` device level.

### Switch Pair Sync

Template ID:

```text
switch_pair_on_off_sync
```

Keeps two switch components synchronized.

Parameters:

| Parameter | Values | Meaning |
| --- | --- | --- |
| Mode | `same`, `inverse` | Same state mirrors on/off; inverse state flips on/off. |
| Sync delay | `immediate`, `delayed` | Delayed mode waits briefly before target-state verification. |

## Troubleshooting

### The device list does not refresh

Check that:

- AEB/EdgeBridge is running,
- `Bridge Address` is correct or mDNS discovery is available,
- AEB/EdgeBridge can forward SmartThings API requests,
- the SmartThings account has device read access.

### Rule create says access is required

Rules management access is checked before create/delete. Confirm AEB/EdgeBridge has a valid SmartThings API token path for Rules list/create/delete.

### A Rule already exists

The driver checks local records and remote Rule names for the `[RG]` hash. Delete the existing owned Rule first if you intentionally want to recreate it with different options.

### Delete mode does not show a Rule

Only driver-owned `[RG]` Rules are shown. Rules created manually or by other tools may not appear.

### A synced switch loops or flips unexpectedly

Try recreating the Switch Pair Sync Rule with `sync_delay = delayed`. Some cloud-backed switch integrations can emit late or transient state events after a command.
