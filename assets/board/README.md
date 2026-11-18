# Gameplay board backgrounds

The Godot scene exposes `board_theme` on the root `CandyMagicRoyale` node.

Available portrait themes:
- `castle` — `board-castle.svg`
- `candy` — `board-candy.svg`
- `crystal` — `board-crystal.svg`

The artwork is rendered on a Sprite3D behind the board. All 8×8 tiles and HUD controls remain in their existing scene positions. Change the exported `board_theme` value in the Inspector to compare the three options.

The project targets 60 FPS through `application/run/max_fps=60`; actual sustained frame rate depends on the Android device and must be profiled on-device.
