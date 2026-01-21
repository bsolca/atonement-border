# ![Atonement Icon](icon.jpg) AtonementBorder

A World of Warcraft addon for Discipline Priests that displays colored borders around unit frames based on Atonement buff duration remaining.

## Screenshot

<!-- TODO: Add screenshot of the addon in action -->
![Screenshot](screenshot.png)

## Features

- **Visual Atonement Tracking** - Colored borders indicate buff duration at a glance
- **Color Coding**:
  - Green: > 5 seconds remaining (healthy)
  - Yellow: 2-5 seconds remaining (warning)
  - Red: < 2 seconds remaining (critical)
- **Performance Optimized** - Built for combat healing without frame drops
- **Multi-Version Support** - Works across different WoW API versions

## Installation

1. Download the addon
2. Extract to your `World of Warcraft\_retail_\Interface\AddOns\` folder
3. Restart WoW or reload UI (`/reload`)

## Slash Commands

| Command | Description |
|---------|-------------|
| `/ab test` | Test Atonement detection on current target |
| `/ab debug` | Toggle debug output |
| `/ab status` | Display current config and tracked frames |
| `/ab enable` | Enable the addon |
| `/ab disable` | Disable the addon |
| `/ab toggle` | Toggle addon on/off |
| `/ab bordersize <1-10>` | Adjust border thickness |
| `/ab pulse` | Toggle pulse animation |

## Configuration

Settings are automatically saved between sessions. Use the slash commands above to customize behavior.
