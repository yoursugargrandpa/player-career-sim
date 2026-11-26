# Game code

`core/` contains engine-independent C# player data models. It is the first code layer for the match and career prototype and can be referenced by a Unity or Godot .NET project after the engine comparison.

The model currently captures the agreed player attributes, goalkeeper attributes, five personality dimensions, player identity, starting age, position, and preferred foot. Outfield and goalkeeper ratings use the agreed 1–100 scale. Personality currently uses a provisional 0–100 scale. Training effects, selection rules, contracts, and match simulation remain separate systems until their rules are defined.
