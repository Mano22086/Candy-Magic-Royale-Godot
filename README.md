# Candy Magic Royale — Godot

Android-first Godot 4 project. This repository is independent from the original web/Babylon.js project.

## Original artwork imported from the old project
- Six transparent candy PNG illustrations from `assets/models/`, used directly on the 3D board.
- Special candy artwork: wrapped candy, peppermint swirl, rainbow gem, and chocolate color ball.
- Booster artwork: magic wand, hammer, rocket, and +5 moves.
- Original start-screen SVG artwork: enchanted garden, castle, Queen Luma, Dragon Prince, and kingdom map.

## Current gameplay
- 8×8 3D board with the original six candy illustrations layered over glossy 3D candy cores.
- Touch/mouse drag to swap adjacent candies.
- Horizontal/vertical match detection, invalid-swap revert, clear, gravity, refill, and cascades.
- Four-match creates a rocket that clears its row or column.
- Five/six-match creates a color ball that clears candies of the swapped color.
- L/T intersections create a wrapped bomb that clears a 3×3 area.
- Special candies trigger chain reactions.
- Moves and score counters.

## Start screen and entry flow
- Recreated the old title-screen layout with the enchanted garden, castle, Queen Luma, Dragon Prince, title, and the original labels `GUEST PLAY` and `FACEBOOK PLAY`.
- GUEST PLAY opens a kingdom map panel; the first house button starts the game.
- FACEBOOK PLAY opens the same explanatory dialog as the old project: real Facebook authentication still needs a Meta app ID/configuration. The dialog offers guest play and back.

## Functional boosters
- Paintbrush: select a candy; it changes to the color that makes the strongest nearby match it can find.
- Shuffle: rearranges the board and searches for a match-free arrangement with a legal move.
- Bomb: select a candy; clears the surrounding 3×3 area.
- Color ball: select a candy; clears every candy of that color.
- Rocket: select a candy; clears its full row.
- +5 moves: adds five moves immediately.
- Each booster has its own remaining-use counter.

## Important media limitation
The old start screen also uses an MP4 cinematic file (about 6.5 MB). The connected GitHub file reader can retrieve text and smaller image assets, but it returned no binary payload for that MP4, so it has **not** been copied into this Godot project. The recreated start screen currently uses the original SVG backdrop and floating character/castle artwork instead of that exact MP4. The start buttons and entry flow are implemented in source.

## Validation status
Source files and original artwork have been committed to this repository. Godot is not installed in this working environment, so this update has **not** been run or parser-tested inside the Godot engine. It is not an Android APK or browser build yet. Runtime validation on Godot 4 and the target phone is still required.
