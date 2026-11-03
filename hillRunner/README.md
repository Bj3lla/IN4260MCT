# Hill Ball — Tiny Wings-style game for Godot 4.3+

Open the folder in Godot (Import → select `project.godot`) and press F5.
The game opens on a title screen where you pick a ball (Left/Right or mouse) and a map
(Up/Down: **Classic**, or **Downhill**, where the whole course slopes gently down), then Enter to play.
The Downhill slope is `MAP_TILTS` in `main.gd` (px of drop per px forward).
Tab picks the mode: **Free play**, or **1 minute**, where the run stops after 60 s
(`ROUND_TIME` in `main.gd`), you type a name and the distance goes on the leaderboard.
The leaderboard only lives in memory, so it resets when the game is closed.

## Controls
- **Push/tilt your device** (or hold **SPACE**) to dive: gravity gets heavier.
- Dive on downslopes to build speed, let go on upslopes to launch off the hill.
- **C** recalibrates the device (hold it still in its neutral pose). **R** restarts. **Esc** returns to the title screen.
- **B** cycles between the rigid ball, the squishy soft-body ball and the jelly ball (rigid movement, soft look).

## Files
| File | What it does |
|---|---|
| `accel_input.gd` | Autoload. Listens on UDP port 4242, converts acceleration into a 0–1 `AccelInput.dive` value. Spacebar fallback. |
| `ball.gd` | RigidBody2D player. `gravity_scale = 1 + 4 * dive`. |
| `soft_player.gd` | Squishy player. Wraps `soft_body_sim/soft_ball.tscn` (from the `soft-body-sim` branch) and applies all forces to its center ball (`rigid_balls[0]`). Tuning exports at the top. |
| `player/jelly_player.gd` | Hybrid ball: moves exactly like the rigid ball, but drawn with a wobbly outline that flattens on the ground, squashes on landings and changes colour when diving. The wobble is visual only. |
| `terrain.gd` | Endless cosine hills generated in chunks; hills grow taller with distance. |
| `menu.gd` | Title screen (`menu.tscn`, the main scene): night-sky backdrop and the ball picker. |
| `ui/` | `ui_style.gd` (shared menu look), `leaderboard.gd` (session scores), `results.gd` (time's-up screen). |
| `main.gd` | Builds the scene, camera (zooms out when you fly high) and HUD. |
| `tools/accel_bridge.py` | Test sender: fake device (`sim`) or forward a serial device (`serial COM3`). |

## Connecting your device
The game listens for UDP packets on port **4242**, one sample per packet, either
`x,y,z` text or JSON `{"x":..,"y":..,"z":..}`.

- **Device on Wi-Fi/network** (ESP32, phone app, etc.): send UDP to your PC's IP, port 4242.
- **Device over USB serial** (Arduino, micro:bit…): print `x,y,z` lines and run
  `pip install pyserial` then `python tools/accel_bridge.py serial COM3` (or `/dev/ttyUSB0`).
- **No device yet**: `python tools/accel_bridge.py sim` sends a fake push every 1.5 s.

The first 30 samples are used as the "rest" baseline, so keep the device still at startup.

## Tuning (select the AccelInput autoload or edit `accel_input.gd`)
- `axis` — which axis means "push" (default Z). Use `(0,0,-1)` if it feels inverted.
- `use_magnitude` — react to any change in acceleration instead of one axis.
- `threshold` / `full_scale` — how hard to push before diving starts / reaches 100%.
  Defaults assume m/s²; if your device reports in g, try 0.1 and 0.5.
- `smoothing` — higher is snappier, lower filters out jitter.

In `ball.gd`:
- `dive_gravity` — how strong diving is.
- `air_gravity` — gravity while flying; lower = floatier, longer flights.
- `launch_boost` — extra upward kick when you leave an upslope without diving.
- `landing_bonus` — max speed gained landing on a steep downslope (default +25%).
- `landing_penalty` — max speed lost landing on a steep upslope (default −40%).

The ground is "ice": the ball's movement is integrated by hand in `_integrate_forces`,
so sliding never loses speed to friction or collisions. Only gravity along the slope
(and the landing rule) changes your speed.
