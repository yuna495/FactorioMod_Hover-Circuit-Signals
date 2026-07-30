# Hover Circuit Signals

Hover Circuit Signals is a small Factorio 2.0 helper mod for inspecting circuit networks without opening an entity GUI.

When you hover over an entity with circuit wires, the mod shows the live circuit signals in a compact window near the bottom-right of the screen. It is intended for debugging combinators, stations, inserters, chests, power poles, and other circuit-connected entities while walking through a factory.

## Features

- Live signal display on hover
- Red and green wire support
- Combinator input and output terminal support where Factorio exposes separate connectors
- Circuit network ID display
- Per-player runtime settings
- Configurable position, column count, maximum signals, update interval, number format, grouping, and sorting
- Optional compact number display
- `Alt + C` hotkey to toggle the display per player
- Single-player and multiplayer compatible

## Usage

Move the mouse cursor over an entity connected to a circuit network. If Factorio exposes circuit connectors and non-zero signals for that entity, a small signal window appears.

Press `Alt + C` to temporarily disable or re-enable the hover window for your player. The hotkey state is stored per player and is preserved when leaving and rejoining a multiplayer game.

## Supported Entity Examples

The mod uses the standard Factorio 2.0 circuit APIs, so support depends on what Factorio exposes for the hovered entity.

Common useful targets include:

- Arithmetic combinators
- Decider combinators
- Constant combinators
- Power poles
- Chests and logistic chests
- Inserters
- Train stops
- Lamps
- Pumps and storage tanks
- Modded entities, when their circuit connectors and signals are available through the standard API

## Settings

All runtime settings are per player.

| Setting | Default | Notes |
|---|---:|---|
| Enable Hover Circuit Signals | On | Enables the hover window. |
| Right Offset | 280 px | Horizontal placement from the bottom-right screen reference. |
| Bottom Offset | 220 px | Vertical placement from the bottom-right screen reference. |
| Columns | 5 | Signal slots per row. |
| Max Signals Shown | 25 | Total slots in the window. When exceeded, the final slot becomes a `+N` tile. |
| Update Interval | 12 ticks | Signal reads and GUI value updates run at this interval. Very short intervals can increase script load. |
| Show Network ID | On | Shows circuit network IDs where a single source is represented in a section; tooltips include source network IDs. |
| Compact Number Format | On | Shows large values with suffixes such as `k`, `M`, and `G`. |
| Separate Input / Output | On | Shows combinator input and output terminals separately when available. |
| Separate Red / Green Wires | On | Shows red and green circuit networks separately. |
| Signal Sort Order | Signal Type / Prototype Name | Sorts by internal signal data, prototype name, or absolute count descending. |

## Number Display

With compact numbers enabled, tile labels are shortened:

| Exact value | Tile label |
|---:|---:|
| 999 | `999` |
| 1,200 | `1.2k` |
| 15,000 | `15k` |
| 2,400,000 | `2.4M` |
| -8,000 | `-8k` |

The tooltip shows the exact value.

## Compatibility

- Factorio 2.0
- Space Age is not required
- Single-player and multiplayer
- Modded entities are supported only to the extent that their circuit connectors and signals are exposed through Factorio's standard runtime API

No additional dependency mods are required.

## Limitations

- Zero-valued signals are normally absent from Factorio circuit signal lists, so only non-zero signals are displayed.
- Entity ghosts and ghost wires are not guaranteed to show live signals.
- Special internal circuits used by some entities or mods may not expose every value through the standard API.
- If several sources are merged by disabling input/output or red/green separation, matching signals are summed by signal type, prototype name, and quality.
- Lowering the update interval can improve responsiveness but may increase script work, especially in multiplayer or when many players hover over active circuit entities.

## Feedback

Please report bugs and compatibility issues on GitHub Issues:

https://github.com/yuna495/FactorioMod_Hover-Circuit-Signals/issues

Source repository:

https://github.com/yuna495/FactorioMod_Hover-Circuit-Signals
