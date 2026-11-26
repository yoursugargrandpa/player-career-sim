# Godot match prototype

This is the first graybox implementation of the match prototype. It uses Godot 4.7.2 stable and built-in primitives; no external assets or plugins are required.

## Open

1. Download the standard Windows x86_64 editor from the [official Godot download page](https://godotengine.org/download/windows/).
2. Extract and launch Godot, then import this folder (`game/prototype`) as a project.
3. Press F6/F5 or use **Run Project**.

The Unity-versus-Godot performance decision is still open. This project is a Godot graybox candidate, not the final engine decision.

## Controls

- Enter: kick off / continue after half-time / restart after full-time
- `+` / `-` before kick-off: set half length from 1 to 20 real minutes (default 6)
- WASD: move relative to the team's attacking direction
- Shift: sprint; Q: close control
- J: short pass; K: through ball; I: lofted pass/cross; L: shoot
- Hold F and press A/D/W/S: dribble move; hold F and press L: fake shot
- Space: header; E: tackle; C: change camera; Esc: pause

This initial version is unverified because the Godot editor was not installed in the workspace when it was created.
