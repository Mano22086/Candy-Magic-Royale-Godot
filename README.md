# Candy Magic Royale — Godot

Independent Godot 4 project for the Android-first Candy Magic Royale game.

## Project files
- `project.godot` — project configuration
- `Main.tscn` — 3D scene, camera, lighting, and HUD
- `scripts/game.gd` — procedural 3D candy board and initial match-3 loop

## Implemented in this source prototype
- 8×8 board with six glossy colored 3D candy shapes
- Touch/mouse drag to swap adjacent candies
- Horizontal and vertical match detection for 3+
- Invalid swaps revert
- Matches clear; candies fall; new candies spawn; cascades resolve
- Moves and score counters

## Run
Open the repository as a Godot 4 project and run `Main.tscn`.

## Current status
This is source code, not a tested Android APK or published web build. It still needs to be opened and run in Godot 4 for runtime validation. A browser-playable link requires a Godot Web export using matching export templates, then publishing the exported files. GitHub source files alone are not a playable build.

## Next passes
1. Runtime validation and engine-version fixes.
2. Special pieces for 4/5/6 matches and L/T patterns.
3. Polished animations, particles, sound, objectives, levels, and boosters.
4. Android profiling/optimization, then Android and Web exports.
