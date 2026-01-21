# AtonementBorder - WoW Addon

## Project Overview
World of Warcraft addon for Discipline Priests that displays colored borders around unit frames based on Atonement buff (spell ID: 194384) duration remaining.

- **Green**: > 5 seconds remaining (healthy)
- **Yellow**: 2-5 seconds remaining (warning)
- **Red**: < 2 seconds remaining (critical)
- **Transparent**: No Atonement buff

## ⚠️ CRITICAL: Performance

**In-game performance is the #1 priority.** This addon runs during active combat healing where frame drops can cause player deaths.

Performance guidelines:
- **Always cache WoW API calls** as local variables at file scope
- **Throttle updates** - never run expensive code every frame
- **Minimize table allocations** during combat (reuse tables, avoid creating new ones in loops)
- **Use early returns** to skip unnecessary work (e.g., check `UnitExists` before processing)
- **Profile changes** using `/ab debug` and watch for chat spam indicating excessive calls

## File Structure
- `AtonementBorder.toc` - Addon manifest (interface version, dependencies, load order)
- `Config.lua` - Default settings, color thresholds, database management
- `AtonementBorder.lua` - Main logic: border creation, frame hooks, event handling, slash commands

## WoW API Compatibility

This addon uses a multi-tier fallback approach for Atonement detection:

1. **Modern API** (preferred): `C_UnitAuras.GetAuraDataBySpellName(unit, spellName, "HELPFUL")`
2. **AuraUtil fallback**: `AuraUtil.FindAuraByName(spellName, unit, "HELPFUL")`
3. **Legacy iteration**: Manual `UnitAura`/`UnitBuff` loop (up to 40 buffs)
4. **Midnight API**: Special handling for duration-secret auras using percentage-based fallback

When modifying aura detection code, maintain all fallback paths for cross-version compatibility.

## Key Patterns

### Local Caching
Frequently used WoW API functions are cached as locals for performance:
```lua
local GetTime = GetTime
local UnitExists = UnitExists
```

### Addon Namespace
Uses `(addonName, AB)` pattern - `AB` is the private addon table for sharing between files.

### Update Throttling
OnUpdate runs at 100ms intervals (not every frame) to balance accuracy and performance.

## Slash Commands for Testing
- `/ab test` - Test Atonement detection on current target
- `/ab debug` - Toggle debug output to chat
- `/ab status` - Display current config and tracked frames
- `/ab enable|disable|toggle` - Control addon state
- `/ab bordersize <1-10>` - Adjust border thickness
- `/ab pulse` - Toggle pulse animation

## Configuration
Settings stored in `AtonementBorderDB` (WoW SavedVariables system). Access via:
- `AB:GetConfig(key)` - Get setting with fallback to default
- `AB:SetConfig(key, value)` - Update setting

## Development Notes
- No build tools required - addon runs directly from WoW's AddOns folder
- Test changes in-game using `/ab debug` and `/ab test`
- Interface version in TOC (120000) corresponds to WoW patch 12.0
