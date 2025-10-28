### Cyclone (Flutter + Flame) — Technical Blueprint

#### Goals
- Recreate the classic single‑screen Cyclone II arcade gameplay with modern UX.
- Prioritize a tight core loop: move, shoot, open gaps, thread shots to core, avoid mines and fatal main shot.
- Build iteratively to enable quick playtesting and tuning.

---

### Architectural Overview
- Engine: Flame 1.17 (Dart 3.9+, Flutter)
- Root: `CycloneGame extends FlameGame with HasCollisionDetection, HasVisibilityDetector`
- Loop: Fixed update (`dt`) with deterministic systems where possible.
- Composition over inheritance: Use Components with mixins for input, collisions, and lifecycle.

#### Core Systems
- Input System
    - Desktop: Keyboard (WASD/Arrows) + space/ctrl for fire.
    - Mobile: Virtual joystick + on‑screen fire button.
- Physics/Collision
    - Use Flame’s `CollisionCallbacks` + `Hitbox*` shapes.
    - Custom broadphase not required; keep entity count modest.
- Entity Management
    - Component tree under `world/` container.
    - Spawn/despawn via factories in `GameManager` and/or `Spawners`.
- Game State
    - `GameManager` holds reactive state (score, lives, level, multipliers, flags) and emits events via Streams/ValueNotifiers.
- UI Overlay
    - Flutter overlays via `GameWidget` overlay mechanism (Score, Lives, Shields, Pause, Game Over, Level Clear).
- Audio
    - Sound effects via Flame Audio cache (`flame_audio` can be added later).
- Effects/Particles
    - Flame `ParticleSystemComponent` for explosions, shield hits, yummy pickups.

---

### Proposed Directory Structure
```
lib/
  main.dart
  game/
    cyclone_game.dart
    game_manager.dart
    input/
      keyboard_controller.dart
      joystick_controller.dart
    ui/
      overlays.dart
      hud.dart
    assets.dart
  components/
    player/
      player.dart
      player_bullet.dart
    enemy/
      enemy_core.dart
      shield_ring.dart
      shield_section.dart
      enemy_main_shot.dart
      mine.dart
    pickups/
      yummy.dart
      yummy_types.dart
  systems/
    collision_tags.dart
    spawners.dart
    scoring.dart
    upgrades.dart
    effects.dart
  utils/
    math_utils.dart
    geometry.dart
    timers.dart
```

---

### Entities and Responsibilities
- Player (`Player extends PositionComponent with KeyboardHandler, CollisionCallbacks`)
    - Movement: 8‑way; speed clamp; friction.
    - Shooting: Bullet pool; max on‑screen bullets default 1 (upgrade to 3 simult.). Cooldown timer.
    - Shields: 0–100%; UI bound; damage: mine −24%; main shot is fatal.
    - Lives: 3; respawn + invulnerability window with blink effect unless “Lock” upgrade engaged.
- PlayerBullet (`Circle hitbox`)
    - Speed, lifetime, owner tag, collision with shield section, enemy core, mines (optional deflection).
- Enemy Core (`EnemyCore extends PositionComponent`)
    - Central triangle rendering; hitbox.
    - Health/phases; on destroy: cascade cleanup (mines, shields) and level clear.
    - Fire logic for main shot: only through existing shield gap; predictive aim possible later.
- ShieldRing (`ShieldRing extends PositionComponent`)
    - Ring metadata: radius, index (inner/mid/outer), sections list, rotation (static at start; optional drift/spin later).
- ShieldSection (`Polygon hitbox, 12 per ring`)
    - Individual HP (1 hit); removal leaves persistent gap.
- EnemyMainShot (single large projectile)
    - Slow telegraphed beam/bolt fired through gap line segment intersecting player position; fatal on hit.
- Mine
    - Spawned by enemy; initial behavior: float to shield ring and attach; may detach and seek player.
    - On contact with player: shield damage or kill.
- Yummy (Pickup)
    - Types: ContinuousFire, TripleBullets, ShieldRefill, Points (1500/3000/4500/9000), Lock, ExtraLife, Multiplier (x3..x6).
    - Spawn sources: destroying shield sections or damaging core.

---

### Data Models
```dart
enum RingIndex { inner, middle, outer }

enum YummyType { continuousFire, tripleBullets, shieldRefill, points1500, points3000, points4500, points9000, lock, extraLife, multiplier3, multiplier4, multiplier5, multiplier6 }

class PlayerState {
  int lives = 3;
  double shields = 100; // 0..100
  bool continuousFire = false;
  int maxSimultaneousBullets = 1; // upgrades to 3
  bool lockUpgradesOnDeath = false;
  int score = 0;
  int scoreMultiplier = 1; // upgrades to 3..6
}

class LevelConfig {
  int levelNumber;
  double enemyHealth;
  Duration mineSpawnInterval;
  // Additional tuning knobs per level.
}
```

---

### Key Algorithms & Mechanics
- Bullet Cap Enforcement
    - Maintain active bullet count. Fire only if `active < maxSimultaneousBullets` and cooldown ready.
- Gap‑Constrained Enemy Shot
    - At fire time, check line segment from core to player position intersects no `ShieldSection` polygons; if clear, spawn `EnemyMainShot`.
    - If no clear path, delay until next check or rotate ring to align gap.
- Shield Ring Geometry (Dodecagon)
    - For each ring, generate 12 wedges with central angle 30°. Store wedge polygons and arc midpoints for mine attach points.
- Mines Behavior State Machine
    - States: `spawned → attaching → attached → detaching → seeking → exploding`.
    - Attach: move to nearest available section edge; stick.
    - Detach/seek: pick target = player position; simple homing with max turn rate.
- Yummy Drops Logic
    - On shield section destroyed: chance to spawn `Yummy` based on table.
    - On core damage: higher chance; clamp total simultaneous pickups.
- Scoring
    - Points per section and pickups; multiplier applied to all score gains.

---

### Collisions Matrix (summary)
- PlayerBullet × ShieldSection → destroy both; spawn particles; chance Yummy.
- PlayerBullet × EnemyCore → apply damage; destroy bullet; on lethal → level clear, nuke mines/shields.
- Player × Mine → −24% shield or death if 0; destroy mine.
- Player × EnemyMainShot → instant death.
- Player × Yummy → apply effect; destroy pickup.

Use `CollisionCallbacks` with `HitboxCircle` (bullets, mines) and `HitboxPolygon` (sections, core, main shot capsule/rectangle).

---

### Rendering & Effects
- Background: solid black (current). Add starfield particles later.
- Player: simple vector shape (triangle/diamond) using `Canvas` draw.
- Enemy: triangle; shield rings rendered as stroked arcs with gaps.
- Explosions: radial particles + screen shake on core death.
- Telegraph for main shot: brief charge glow through gap before firing.

---

### UI/Overlays
- HUD: score (with multiplier), lives icons, shield bar, plus a Pause/Exit controls row directly beneath the HUD (elements spaced by 12px).
- Pause Menu: Resume, Restart, Quit.
- Game Over: final score and retry.
- Level Clear: summary and continue.

---

### Current Sprints (max 3)
1. Core Play Controls ✓
   - Home screen with title 'Cyclone' and centered layout; black bg, amber text, red buttons. ✓
   - High Score list (max 5) and Last Player (editable name, shows last score/level). ✓
   - On-screen joystick (bottom-left) and FIRE button (bottom-right). ✓
   - Player rotation toward movement; up to 3 inline bullets from ship tip. ✓
   - Starfield background (static white dots). ✓
2. Enemy Sprite (Center-Tracked) ✓
   - Remove legacy enemy core and shield rings from gameplay. ✓
   - Add a stationary enemy ship sprite pinned to screen center. ✓
   - Enemy sprite rotates to face the player's ship each frame. ✓
3. Visual & Loop Polish *
   - Player ship uses stationary vs moving sprites depending on motion. ✓
   - Review scoring and game reset flow with the new enemy setup. *
   - Plan next interactions (e.g., simple enemy fire or collision rules) consistent with sprite-based enemy. *

(✓ = implemented in this update; * = next focus)

---

### Initial Interfaces (pseudocode)
```dart
class CycloneGame extends FlameGame with HasCollisionDetection {
  late final GameManager gm;
  @override Future<void> onLoad() async {
    gm = GameManager();
    addAll([ /* player, enemy, rings, hud anchors */ ]);
  }
}

class GameManager {
  final player = PlayerState();
  final level = LevelConfig(/*...*/);
  final score = ValueNotifier<int>(0);
  final lives = ValueNotifier<int>(3);
  final shields = ValueNotifier<double>(100);
  void addScore(int base) { score.value += base * player.scoreMultiplier; }
}

class Player extends PositionComponent with KeyboardHandler, CollisionCallbacks {
  final bulletCooldown = 0.18;
  int activeBullets = 0;
  @override void update(double dt) { /* movement + fire */ }
  void tryFire() {
    if (activeBullets < maxSimultaneousBullets && cooldownReady) spawnBullet();
  }
}
```

---

### Asset Plan
- Start vector/primitive; no textures needed initially.
- Add lightweight SFX later: shoot, hit, pickup, explode.

---

### Testing Strategy
- Unit: geometry (dodecagon section positions, line‑of‑sight through gaps), upgrade effects, scoring multiplier.
- Integration: collisions (bullet–section/core), mine behavior transitions, fatal shot pathing.
- Golden tests for HUD layout (optional).

---

### Next Steps (Actionable)
- Enemy Skeleton: Add `EnemyCore` component at center with simple triangle render and basic health (no attack yet).
- Shield Rings: Implement three dodecagonal rings (geometry + render placeholders) with 12 sections each.
- Collisions: Enable PlayerBullet × ShieldSection to remove a section and the bullet (gap creation), no particles yet.

---

### Recent Fixes (v1.7.1)
- Fixed asset loading on all targets by setting Flame `images.prefix = 'assets/'` to match our asset layout; sprites now load from `assets/*.png` instead of the default `assets/images/*.png`.

### Recent Updates (v1.7.0)
- Removed legacy enemy core and shield rings from gameplay.
- Added a new stationary enemy ship sprite pinned to the screen center that rotates to face the player's ship.
- Player ship now uses `assets/ship_sprite_stationary.png` when idle and `assets/ship_sprite_moving.png` during movement.

### Recent Updates (v1.6.0)
- Enemy and shield rings render as solid glowing lines with 8px thickness; outer red (CW), middle orange (CCW), inner yellow (CW).
- Enemy core remains centered on screen on resize and continuously rotates to face/follow the player's ship.
- Main shot now fires only when a clear line exists through gaps across all three rings and is fatal to the player on hit (one-hit kill).
- Added a quick glow-burst explosion effect on player destruction.

### Recent Fixes (v1.5.1)
- HUD pills now render side-by-side using a `Wrap` with spacing, preventing vertical stacking on narrow widths and improving responsiveness on tablet/web.

### Recent Fixes (v1.2.1)
- Wrapped `GameWidget` in a `MaterialApp` + `Scaffold` to provide `MaterialLocalizations` and an `Overlay` ancestor, fixing TextField/Slider/ChoiceChip assertions on the Home screen.
- Hardened `SharedPreferences` access in `GameManager` with try/catch to avoid crashes on iOS/macOS hot‑restart (`MissingPluginException`); app now continues with defaults and logs the issue. A full app restart resolves the plugin state.
