# Cyclone (Flutter + Flame)

Recreating the classic single-screen Cyclone II arcade gameplay with modern UX, built with Flutter and the Flame game engine. Focused on a tight core loop: move, shoot, open gaps in rotating shields, thread shots to the enemy core, avoid mines, and dodge a telegraphed fatal main shot.

- Engine: Flame 1.17 (Dart 3.9+, Flutter)
- Architecture: Composition-first Flame Components, fixed update loop, collision detection via Flame
- Platforms: Desktop (keyboard) and Mobile (virtual joystick + on-screen fire)

## Features

- Player: 8-way movement, friction, capped bullet firing with cooldown, shields, lives, respawn i-frames
- Enemy: Central core with phases/HP; rotating shield rings composed of destructible sections
- Attacks:
    - Player bullets: collide with shield sections and core through gaps
    - Enemy main shot: slow, telegraphed, fires only through an existing shield gap; fatal on hit
    - Mines: attach to shield, can detach and home toward player
- Pickups (“Yummies”): upgrades and points (continuous fire, triple bullets, shield refill, lock, extra life, multipliers, points)
- UI Overlays: HUD (score, lives, shields), Pause, Game Over, Level Clear
- Particles and effects for hits, explosions, and telegraphs
- Deterministic-friendly fixed update loop; modest entity counts

## Tech Stack

- Flutter + Dart 3.9+
- Flame 1.17 (with HasCollisionDetection, ParticleSystem, GameWidget overlays)
- Optional: flame_audio for SFX

## Project Structure

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


## Gameplay Overview

- Destroy shield sections to open gaps; thread shots to damage the core
- Mines damage shields by 24% on contact; death if shields at 0
- Enemy main shot is instantly fatal but only fires through a valid gap to the player
- Score multipliers apply globally; upgrades can persist with “Lock”

## Core Systems

- Input: Keyboard (WASD/Arrows + Space/Ctrl), Virtual joystick + fire button on mobile
- Collisions: HitboxCircle (bullets, mines), HitboxPolygon (sections, core, shot capsule)
- Entity Management: Component tree under world/, spawners and factories in GameManager
- Game State: Reactive score, lives, shields, level config via ValueNotifiers/Streams
- UI: Flutter overlays for HUD and menus
- Audio: Lightweight SFX later via flame_audio
- Effects: ParticleSystemComponent for hits/explosions/pickups

## Entities

- Player: 8-way movement, bullet pool, bullet cap (default 1, upgrade to 3), cooldown; shields 0–100; lives 3; respawn with blink; optional lock to persist upgrades
- PlayerBullet: Circle hitbox, speed/lifetime, collisions with shield sections/core/mines
- EnemyCore: Central triangle, HP/phases, spawns main shot through gaps, cascade cleanup on death
- ShieldRing/Section: Three rings, 12 wedge sections each (dodecagon), per-section HP 1, gaps persist
- EnemyMainShot: Telegraphed beam/bolt, fatal, fired only if line to player is clear through gaps
- Mine: Attach to shield, may detach and home; damages shields or kills
- Yummy: Multiple upgrade/points types; drops from section destruction or core damage

## Algorithms

- Bullet cap: active bullets < maxSimultaneousBullets and cooldown ready
- Gap-constrained shot: line segment core→player must not intersect any shield section polygon
- Dodecagon ring geometry: 12 wedges, 30° each; store polygons and arc midpoints
- Mine state machine: spawned → attaching → attached → detaching → seeking → exploding
- Scoring: multiplier applied to all gains; drops table controls pickup spawns

## Collision Matrix (summary)

- PlayerBullet × ShieldSection: both destroyed, particles, chance to drop Yummy
- PlayerBullet × EnemyCore: damage core, destroy bullet; on lethal, clear level and nuke mines/shields
- Player × Mine: −24% shield or death if 0; destroy mine
- Player × EnemyMainShot: instant death
- Player × Yummy: apply effect; destroy pickup

## Rendering

- Black background; vector shapes for player/enemy
- Shield rings rendered as stroked arcs with gaps
- Explosions: radial particles + screen shake on core death
- Telegraph: brief charge glow through the active gap before firing

## Data Models (sketch)

- Enums: RingIndex(inner/middle/outer), YummyType(continuousFire, tripleBullets, shieldRefill, points, lock, extraLife, multiplier x3..x6)
- PlayerState: lives, shields, flags for upgrades, score, multiplier
- LevelConfig: per-level tuning (enemy health, mine spawn interval, etc.)

## Testing

- Unit: ring geometry, line-of-sight through gaps, upgrades, scoring
- Integration: collisions (bullet–section/core), mine transitions, fatal shot pathing
- Optional golden tests for HUD layout

## Roadmap

1) Bootstrap ✓
2) Player core: movement + bullet cap/cooldown
3) Enemy core skeleton
4) Shield rings geometry + rendering
5) Bullet vs shield collisions with particles + drops
6) Bullet vs core with line-of-sight through gaps
7) Game state + HUD overlay
8) Mines (basic) attach/seek collisions
9) Shield damage and death/respawn
10) Enemy main shot with telegraph and gap constraint
11) Win/Loss flows and screens
12) Yummies (all upgrades) including Lock
13) Polish, tuning, SFX, starfield, UX, settings

## Getting Started

Prerequisites:
- Flutter SDK and Dart 3.9+
- Flutter desktop/mobile setup as desired

Install:
- flutter pub get

Run:
- flutter run -d <device_id>

Build:
- flutter build <platform>

## Configuration

- Game tuning via LevelConfig and GameManager
- Input automatically adapts by platform (keyboard vs virtual joystick)
- Optional audio: add flame_audio and preload assets

## Contribution

- Open issues for bugs/feature requests
- Use small, reviewable PRs aligned to milestones
- Include unit/integration tests for gameplay changes

## License

Specify your preferred license (e.g., MIT) in LICENSE.

## Maintainers

- AI Assistant (contact: open a GitHub issue)
