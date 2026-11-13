# stop-waiting-for-godot-jam — web port (Godot 3.3, GDScript)

Same project, C# scripts ported to GDScript so it can export to HTML5.

## Export to browser
1. Install **Godot 3.3.x standard** (NOT the Mono build) + its export templates
   (Editor > Manage Export Templates).
2. Open this folder (project.godot). Let it import assets once.
3. Project > Export > preset "HTML5" > Export Project -> `build/index.html`.
4. Serve the `build/` folder over http (browsers block file://):
   `python3 -m http.server -d build 8000`  then open http://localhost:8000
   Upload the same folder to itch.io / any static host (zip it, tick "SharedArrayBuffer" is NOT needed in 3.3).

Controls: W/S throttle, A/D steer, R restart, C change camera. Click the game once so it gets keyboard focus + audio.

## What changed vs the C# build
- scripts/*.cs -> scripts/*.gd (same logic, same exported variable names).
- Best time/splits (C# statics) -> autoload scripts/Persist.gd.
- Dirt: GPU `Particles` -> `CPUParticles` (GLES2 has no GPU particles); settings copied from the CPUParticles test node in main.tscn.
- track.fbx -> track/track.glb; collider is generated in Game.gd.
- config.ini now loaded from res://config.ini (included via export filter).
- Removed unused ParticlesTest / CrateMover2 / test C# node.

## Known visual differences in web (GLES2)
SSAO and contact shadows are not available; glow is limited. Everything else (fog, sky, adjustments, shadows) is supported.
