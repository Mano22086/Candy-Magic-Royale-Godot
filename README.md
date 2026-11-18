# Candy Magic Royale — Godot

Independent Godot 4 project for the Android-first Candy Magic Royale game.

## Project files
- `project.godot` — project configuration
- `Main.tscn` — 3D scene, camera, lighting, and HUD
- `scripts/game.gd` — 3D candy board, match detection, special pieces, and cascade loop

## Implemented in source
- 8×8 board with six glossy colored 3D candy shapes
- Touch/mouse drag to swap adjacent candies
- Horizontal and vertical match detection for 3+
- Invalid swaps revert
- Match 4 creates a directional rocket
- Match 5 or 6 creates a color bomb
- L/T intersections create a wrapped area bomb
- Rockets clear a full row or column
- Wrapped bombs clear a 3×3 area
- Color bombs clear all candies of the swapped color
- Special pieces trigger chain reactions and have activation/creation animations
- Matched candies clear, remaining candies fall, new candies spawn, and cascades resolve
- Moves and score counters

## Run
Open the repository as a Godot 4 project and run `Main.tscn`.

## Current status
This is source code, not a tested Android APK or published web build. It still needs to be opened and run in Godot 4 for runtime validation. Special-piece logic has been added in source but has not yet been verified in a live engine session. A browser-playable link requires a Godot Web export using matching export templates, then publishing the exported files. GitHub source files alone are not a playable build.

## Next passes
1. Run in Godot 4 and fix any parser/runtime issues.
2. Add dedicated high-quality particle/beam effects and sound for each special.
3. Add level goals, blockers, hearts, boosters, progression, and save data.
4. Profile and optimize on the target Android device, then prepare Android and Web exports.
