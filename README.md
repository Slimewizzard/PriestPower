# PriestPower

PriestPower is a priest-focused addon for World of Warcraft 1.12.1 (specifically optimized for **Turtle WoW**). Inspired by the classic PallyPower, it simplifies raid-wide buff management and provides specialized tracking for unique Priest class features.

## Features

- **Smart Buff Management**: Easily assign and track **Power Word: Fortitude**, **Divine Spirit**, and **Shadow Protection** across raid groups.
- **Turtle WoW Support**: Fully supports **Enlighten** and specialized **Champion** spells:
  - *Proclaim Champion*
  - *Champion's Grace*
  - *Empower Champion*
  - *Revive Champion*
- **3-State Shadow Protection**: Cycle between **Prayer** (20m group), **Standard** (10m single), and **Off** to maximize mana efficiency and coverage.
- **Modern HUD (BuffBar)**:
  - **Dynamic Scaling**: Drag the bottom-right corner to "Zoom" the UI to your preferred size.
  - **Smart Visibility**: Only shows buttons for missing buffs or active assignments.
  - **Target Cycling**: Click the single-buff icons to automatically target and cast on players missing their buffs.
- **Raid Coordination**: Syncs seamlessly with other PriestPower users to ensure everyone knows their assignments.
- **Pure Lua UI**: Rewritten for high performance and stability, removing the dependency on legacy XML templates.

## Commands

- `/prip`: Toggle the main Configuration window.
- `/prip reset`: Resets the UI position and scale to default settings.
- `/prip debug`: Toggles internal debug logging.
- `/prp`, `/priestpower`: Alternative aliases for `/prip`.

## Configuration

1. Use `/prip` to open the assignment grid.
2. Click the icon for a class/group to cycle between **Greater Buff** (three figures), **Single Buff** (single figure), and **Off** (grey).
3. Assignments are automatically synced with other priests in the raid.
4. Scale the UI by dragging the resize grip (bottom-right) of either the Config window or the BuffBar.

## Installation

1. Download the addon.
2. Extract the `PriestPower` folder into your `Interface\AddOns` directory.
3. Ensure the folder name is exactly `PriestPower`.

## Credits

- Originally based on **PallyPower** by Relar.
- Adapted and modernized for **Turtle WoW** and the Priest class.
