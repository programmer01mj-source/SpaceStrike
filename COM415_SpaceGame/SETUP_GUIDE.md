# SPACE STRIKE – Setup & Modification Guide

A complete 3D arcade space-combat game for **Godot 4.7.2 (GDScript)**, made for COM415.
Everything works **right now** with the resources you uploaded. Two things are left for you to add:

| Missing resource | Folder in the project | What happens until you add it |
|---|---|---|
| Spaceship models | `spaceships/` | Simple built-in placeholder ships are used |
| Audio files | `audio/` | Short built-in beeps for lasers/explosions; no music |

You do **not** need to write any code to add them. Part 2 and Part 3 below are written as click-by-click steps.

---

## PART 1 – Open and run the game (do this first)

1. Install **Godot 4.7.2** (standard version, not .NET) from godotengine.org if you do not have it.
2. Unzip `COM415_SpaceGame.zip` somewhere simple, e.g. `C:\Projects\COM415_SpaceGame`.
3. Start Godot. In the Project Manager click **Import**, browse to the unzipped folder, select the file **`project.godot`**, click **Open**, then **Import & Edit**.
4. Wait about a minute: Godot is importing all the models/images (a progress bar shows at the top right). This only happens the first time.
5. Press **F5** (or the ▶ button at the top right) to run the game.
   - If Godot asks *"Select a main scene"*, choose `game/scenes/main_menu.tscn`.
6. Test controls on your computer:
   - **W A S D / arrow keys** = steer, **Space** = fire, **Shift** = boost, **Esc** = pause.
   - On a phone/tablet: drag your left thumb on the left half of the screen to steer, hold the red **FIRE** button, hold the blue **BOOST** button.

> If you see a yellow warning triangle in the Output panel about "invalid UID", ignore it. It is harmless.

### Game flow (matches the assignment)
`Main Menu → Start Game → choose ship + mission → LAUNCH → play level → destroy the required enemies → fly through the glowing JUMP GATE → Mission Complete → Main Menu`
(If you die: **Game Over → Try Again / Main Menu**.)

---

## PART 2 – Add the SPACESHIP folder

### What the game does with your ships
* The game has **3 player ships** (Falcon, Titan, Phantom) and **2 enemy types** (Fighter, Gunship). That is **5 model slots**.
* Models are **found automatically** in `res://spaceships/`, sorted by file name, and assigned in this order:

| Alphabetical position | Used as |
|---|---|
| 1st file | Player ship 1 – FALCON |
| 2nd file | Player ship 2 – TITAN |
| 3rd file | Player ship 3 – PHANTOM |
| 4th file | Enemy – FIGHTER |
| 5th file | Enemy – GUNSHIP |

* If you have **fewer than 5** models, the list simply repeats from the start. If you have **more than 5**, the extras are ignored (until you choose them yourself – see Step 6).
* Each model is **automatically centred and scaled** to a sensible size, so you do not need to resize anything.
* Supported types: `.gltf`, `.glb`, `.fbx`, `.obj` (and `.tscn`). If the same ship exists in several formats (e.g. `Bob.gltf` and `Bob.fbx`), the game uses just one – GLTF is preferred.

### Steps

**Step 1 – Copy the models.**
Open your computer's file explorer (NOT Godot) and open the project folder. You will see an (almost empty) folder called **`spaceships`**. Copy **all the files from your spaceships folder into it** (sub-folders are fine). Delete nothing else.
Make sure textures that come with the models (`.png`, `.jpg`, `.bin`) are copied **too**, in the same place as the model files.

**Step 2 – Let Godot import them.**
Switch back to Godot. It notices the new files and shows *"Importing…"* for a few seconds. In the **FileSystem** dock (bottom left) you should now see your files under `res://spaceships/`. If not, click the FileSystem dock and press **F5**-refresh by switching to another window and back.

**Step 3 – Run and look.**
Press **F5 → START GAME**. On the ship-selection screen use **PREV / NEXT**: you will see your models spinning in the preview. Pick one and **LAUNCH**.

**Step 4 – If a ship flies sideways or backwards** (very common – every artist uses a different "front"):
1. In Godot's **FileSystem** dock, open `game/data/` and **double-click `ship_catalog.gd`**.
2. Find the ship that looks wrong, for example:
   ```gdscript
   "model_file": "",
   "model_yaw_degrees": 0.0,
   ```
3. Change `model_yaw_degrees` to one of these, then save with **Ctrl+S** and run again:
   * ship flies **backwards** → `180.0`
   * ship's nose points **to the right** → `90.0`
   * ship's nose points **to the left** → `-90.0`
4. Enemies use the same setting inside the **ENEMY_TYPES** block further down.

**Step 5 – If ships look too big or too small.**
In the same file, near the top, change these two numbers (metres, longest side of the ship):
```gdscript
const PLAYER_MODEL_SIZE := 5.0
const ENEMY_MODEL_SIZE := 5.5
```

**Step 6 – (Optional) Choose exactly which model is which.**
In `ship_catalog.gd` type the **exact file name** (with extension) between the quotes:
```gdscript
"model_file": "Striker.gltf",
```
Do this for each of the 3 `PLAYER_SHIPS` and the 2 `ENEMY_TYPES`. Leave `""` to keep the automatic choice. The name is case sensitive and must match a file somewhere inside `spaceships/` – use the file name only, e.g. `"Striker.gltf"`, if the file is directly in `spaceships/`. If it is in a sub-folder write the path, e.g. `"GLTF/Striker.gltf"`.

**Step 7 – (Optional) Re-balance ships.**
In the same file you can change `max_speed`, `acceleration`, `turn_rate`, `max_health`, `damage`, and the names/descriptions. The bars in the selection screen update automatically.

### Ship troubleshooting
| Problem | Fix |
|---|---|
| Still seeing plain coloured block ships | Files are not in `res://spaceships/`, or Godot has not finished importing. Check the FileSystem dock. |
| Ship is white / has no colours | Copy the texture files (`.png`/`.jpg`) next to the model, wait for re-import. |
| Ship is tilted/rotated oddly | Use `model_yaw_degrees` (Step 4). If it is tilted in other ways, re-export the model with "+Y up". |
| Warning "model_file ... was not found" in Output | Typo in the file name in `ship_catalog.gd`. |

---

## PART 3 – Add the AUDIO folder

### What the game does with your audio
All sound is controlled by `game/autoload/audio_manager.gd`. Your files are **found automatically by words in the file name**. Example: a file called `laser_shot_01.wav` is used as the player's laser, because its name contains "laser".

**Sound effects the game plays**

| Game event | Put one of these words in the file name | Exact-name key |
|---|---|---|
| Player fires | `player_laser`, `laser`, `shoot`, `blaster`, `pew`, `fire` | `player_laser` |
| Enemy fires | `enemy_laser`, `enemy_shoot` (otherwise uses the player laser sound) | `enemy_laser` |
| Any ship explodes | `explosion`, `explode`, `boom`, `blast`, `destroy`, `crash` | `explosion` |
| Player is hit | `hit`, `impact`, `damage`, `hurt`, `bump` | `hit` |
| Boost starts | `boost`, `afterburner`, `thruster`, `whoosh`, `engine` | `boost` |
| Low health / gate open alert | `warning`, `alarm`, `alert`, `siren` | `warning` |
| Mission complete | `victory`, `win`, `complete`, `success`, `fanfare` | `victory` |
| Game over | `game_over`, `gameover`, `lose`, `defeat`, `fail` | `game_over` |

**Music (loops automatically)**

| Where | File-name words | Exact-name key |
|---|---|---|
| Main menu | `menu`, `title`, `intro`, `theme` | `menu` |
| Level 1 (space) | `space`, `level1`, `battle`, `combat`, `action` | `space` |
| Level 2 (planet) | `planet`, `level2`, `surface`, `canyon`, `combat` | `planet` |

(If a level has no matching music file, any file whose name contains `music` or `loop` is used. Button click sounds come from the Kenney UI pack and already work.)

### Steps

**Step 1 – Copy the audio.** In your file explorer open the project folder and copy **all your audio files** (`.ogg`, `.wav`, `.mp3`) into the empty **`audio`** folder. Sub-folders are fine.
*Tip: `.ogg` is best for music (small) and `.wav` for short effects.*

**Step 2 – Rename if needed (easiest method).** Look at the table above. For every file that should be used for a game event, make sure its **name contains one of the words** in the right column. You can rename files in your file explorer, e.g. `sfx_17.wav` → `explosion_big.wav`, `track3.ogg` → `space_battle_music.ogg`.

**Step 3 – Wait for Godot to import**, then press **F5** and play. Listen for the sounds.

**Step 4 – (Alternative) Choose files by exact name, with no renaming.**
1. In Godot's FileSystem dock open `game/autoload/` and double-click **`audio_manager.gd`**.
2. Find the block `const SOUND_FILES := { ... }` and type your file name (relative to the `audio` folder) between the quotes:
   ```gdscript
   const SOUND_FILES := {
   	"player_laser": "sfx/zap01.wav",
   	"enemy_laser": "sfx/zap02.wav",
   	"explosion": "boom_big.ogg",
   	...
   }
   ```
3. Do the same for music in `const MUSIC_FILES := { ... }`:
   ```gdscript
   	"menu": "music/title_theme.ogg",
   	"space": "music/battle_1.ogg",
   	"planet": "music/battle_2.ogg",
   ```
4. Save with **Ctrl+S**.

**Step 5 – Change loudness.** In `audio_manager.gd` change `var music_volume_db: float = -8.0` (more negative = quieter) and `var sfx_volume_db: float = 0.0`.

### Audio troubleshooting
| Problem | Fix |
|---|---|
| No music | No file name contains the keywords. Rename the file (Step 2) or type the exact name (Step 4). |
| A sound plays the wrong event | Rename the file so its name doesn't contain another event's word (e.g. a file named `explosion_hit.wav` matches both). Or use Step 4. |
| Beep sounds instead of my sound | The game could not find your file; check spelling and the folder. |
| Warning "'res://audio/…' not found" | Typo in an exact name in `SOUND_FILES` / `MUSIC_FILES`. |

---

## PART 4 – Other things you may want to change

| I want to… | Open this file | Change |
|---|---|---|
| Change number of enemies to kill | `game/data/level_catalog.gd` | `"enemy_goal"` |
| Make enemies easier/harder | `game/data/ship_catalog.gd` (ENEMY_TYPES) | `max_health`, `damage`, `fire_interval`, `detect_range`, `attack_range`, `max_speed` |
| Change laser rate/speed | `game/player/player_ship.gd` | `FIRE_INTERVAL`, `BOLT_SPEED` |
| Change boost power | `game/player/player_ship.gd` | `BOOST_MULTIPLIER`, `BOOST_DRAIN_PER_SECOND` |
| Camera distance / feel | `game/player/chase_camera.gd` | `follow_offset`, `position_lag` |
| Aim assist strength | `game/player/player_ship.gd` | `AIM_ASSIST_COS` (closer to 1.0 = weaker) |
| Rock/planet layout, add scenery | `game/levels/space_world.gd` or `planet_world.gd` | `add_obstacle(...)` / `add_decoration(...)` lines (any model name from `assets/environment`) |
| Add a 3rd level | copy `space_world.gd` → new world script, then add an entry to `LEVELS` in `level_catalog.gd` | |
| Button / panel look | `game/ui/ui_theme.gd` | texture paths |

---

## PART 5 – Put the game on an Android phone (short version)
1. Godot menu **Editor → Manage Export Templates → Download and Install**.
2. Install **JDK 17** and the **Android SDK** (Android Studio does both), then in **Editor → Editor Settings → Export → Android** set the *Java SDK Path* and *Android SDK Path*.
3. **Project → Export → Add… → Android**. Turn on **Use Gradle Build** only if you need it; otherwise leave defaults. Under *Options → Architectures* tick **arm64-v8a**.
4. Plug in your phone (USB debugging on) and click the small **Android icon** (top right) → *Deploy with Remote Debug*, or press **Export Project** to make an `.apk`.
5. If a very old phone shows a black screen, open **Project Settings → Rendering → Renderer** and change *Rendering Method* from `mobile` to `gl_compatibility`.

---

## PART 6 – How the assignment requirements are met

| Requirement | Where |
|---|---|
| Godot 4.7.2 + GDScript | whole project |
| 3D, third-person (EverSpace 2 style) chase camera | `game/player/chase_camera.gd` |
| Touch controls (virtual joystick + buttons), keyboard fallback | `game/ui/ship_joystick.gd`, `touch_button.gd` |
| 3 player ships with different speed/acceleration | `game/data/ship_catalog.gd` |
| 2 levels (space, planet surface) with Environment models | `game/levels/space_world.gd`, `planet_world.gd` |
| 2 enemy types, flying, shooting | `game/ai/enemy_ship.gd` |
| Finite State Machine (Wander / Chase / Attack) | `game/ai/fsm/` |
| GDQuest Steering AI Framework (follow path, pursue, seek, separation + custom wander & obstacle avoidance) | `addons/com.gdquest.godot-steering-ai-framework`, `game/ai/steering/` |
| Flight Navigation 3D (voxel path-finding around obstacles) | `addons/flight_navigation_3d`, `game/levels/level_controller.gd`, `path_service.gd` |
| UI (Kenney pack): menus, HUD, health, pause, game over | `game/ui/` |
| Particles (explosions, sparks, engine exhaust, space dust) | `game/fx/effects.gd` |
| Win condition and game flow | `game/levels/level_controller.gd` |

### Credits (keep these in your report)
* Steering AI Framework – GDQuest (MIT licence)
* Flight Navigation 3D – Trần Lâm (MIT licence)
* Kenney UI Pack, Crosshair Pack, Mobile Controls – kenney.nl (CC0)
* Environment models – the Environment pack you supplied (check its licence)

---

## PART 7 – Quick troubleshooting
| Problem | Fix |
|---|---|
| "Invalid UID" warnings | Harmless. |
| Level loading takes a few seconds | Normal: the flight-navigation grid is built at start (about 1–3 s on a PC, a little longer on phones). To make it faster lower `nav_layers` from 6 to 5 in the world script (enemies then path-find less accurately). |
| Phone runs slowly | Lower shadows: in `planet_world.gd` change the `add_sun(..., true)` last argument to `false`; reduce the `range(110)` / `range(46)` plant/tree counts. |
| Joystick not responding on PC | Click inside the game window first; or use the keyboard (WASD). |
| Everything is too hard | Lower the enemy `damage` in `ship_catalog.gd` or raise the ship `max_health`. |
