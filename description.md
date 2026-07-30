# Hover Circuit Signals

Hover Circuit Signals shows live circuit network signals by mouse hover, without opening the entity GUI.

Hover over a circuit-connected entity to see a compact signal window with the current non-zero signals. It supports red and green wires, combinator input/output terminals where Factorio exposes them, circuit network IDs, sorting, compact number labels, and per-player display settings.

You can configure the window position, number of columns, maximum displayed signals, update interval, network ID display, compact number formatting, input/output grouping, red/green grouping, and sort order.

Press `Alt + C` to toggle the hover display for your player.

Compatibility:

- Factorio 2.0
- Space Age is not required
- Single-player and multiplayer
- Modded entities are supported only when their circuit connectors and signals are available through the standard Factorio runtime API

Limitations:

- Zero-valued signals are normally not present in circuit signal lists, so they are not displayed.
- Entity ghosts and ghost wires are not guaranteed to show live signals.
- Some special internal circuits from Factorio or other mods may not expose every value through the standard API.
- Very short update intervals can increase script load, especially in multiplayer.
