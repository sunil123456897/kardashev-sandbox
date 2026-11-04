# Project: Kardashev Sandbox — Crucible of Stars (Godot 4.7)

## Architecture
- **Engine**: Godot 4.7.2 Forward Plus / CanvasItem 2D pixel-art simulation.
- **Root Scene**: `res://scenes/main.tscn` with `scripts/main.gd`.
- **Node Composition**:
  - `WorldSimulation` (`scripts/sim/world_simulation.gd`): Pure simulation domain model (grid, tiles, actors, cities, diplomacy, megastructures, god powers). Communicates via signals.
  - `CosmicRenderer` (`scripts/render/cosmic_renderer.gd`): 2D pixel-art canvas rendering, dynamic planet texture buffer, actors, structures, orbital sails, particles, and 2D visual effects.
  - `SandboxOrbitCamera` (`scripts/render/orbit_camera.gd`): 2D camera with smooth panning, zoom, deadzone, and target framing.
  - `GodHUD` (`scripts/ui/god_hud.gd`): User interface, toolbars, modal inspectors, event logs, time controls, and analytics.
  - `AudioSubsystem` (`scripts/audio/audio_subsystem.gd`): Audio bus manager, procedural SFX synthesizer, and ambient cosmic soundscape.
- **Data & Asset Layer**:
  - `SandboxAssetManager` (`scripts/core/asset_manager.gd`): Biomes, subspecies traits, god powers, world laws, build orders, and tech codex.
  - `SandboxAsset` (`scripts/core/sandbox_asset.gd`): Data models for entities, tiles, traits, plots, and megastructures.

## Feature Inventory
Every feature from user requirements and acceptance criteria is cataloged and assigned to a milestone:
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | F1: Polis Internal Org & Ideology | Societal ethos, cultural traits, council leadership, and internal city cohesion | M1 | R1, AC-1 |
| 2 | F2: Inter-Polis Diplomacy & War | Diplomatic relations matrix (peace, trade, alliances, wars) driven by `PlotAsset` | M1 | R1, AC-1 |
| 3 | F3: Inter-Island Colonization | Colonist expedition parties / colony ships founding daughter settlements | M1 | R1, AC-1 |
| 4 | F4: 4-Stage Dyson Megastructure | Swarm Collectors -> Ring Frame -> Shell Segments -> Matrioshka Brain with resource drain and energy yield | M2 | R1, AC-2 |
| 5 | F5: Expanded Divine Intervention Powers | Destructive cataclysms (meteor, antimatter, quake), biosphere mutagenics, alchemy, and building/actor damage | M2 | R2, AC-3 |
| 6 | F6: World Physical Laws & Constants | Configurable continuous constants ($G$, entropy, light speed) & alchemical reaction matrix | M2 | R2, AC-3 |
| 7 | F7: Audio Subsystem & SFX/Ambient | Audio buses, procedural sound synthesizer, action/cataclysm SFX, and atmospheric ambient | M3 | R3, AC-4 |
| 8 | F8: 2D Visual Effects & Shaders | 2D CanvasItem shaders (Dyson glow, distortion aura), status badges, and 2D particle systems | M3 | R3, AC-4 |
| 9 | F9: Advanced God HUD & Inspectors | Dedicated Polis Inspector, Actor Inspector, Culture Inspector, Global Metrics chart, interactive event log | M3 | R3, AC-5 |
| 10 | F10: Performance & 25x Time Warp Stability | Dirty-rect / cached pixel map rendering and deterministic substepped behavior timers | M4 | R4, AC-1 |
| 11 | F11: Comprehensive Headless Automated Tests | Full test suite in `tests/` covering R1-R4, 100% passing with exit code 0 | M4 & E2E Track | AC-6, AC-7 |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Civilization Deepening, Diplomacy & Colonization | F1 (Org/Culture), F2 (Diplomacy/War/Trade), F3 (Colonization) in `scripts/sim/` and `scripts/core/` | none | DONE |
| M2 | Megastructures, World Laws & Divine Arsenal | F4 (4-Stage Dyson), F5 (Destructive Powers & Damage), F6 (World Constants & Alchemy Matrix) | M1 | DONE |
| M3 | Audiovisual Atmosphere, Shaders & UI Inspection | F7 (Audio Subsystem), F8 (2D Shaders & Particles), F9 (Inspectors & Metrics HUD) | M2 | DONE |
| M4 | Performance, Stability & Final E2E Integration | F10 (Dirty-rect render & 25x tick stability), F11 (E2E Test Suite pass 100% + Tier 5 Hardening) | M3, TEST_READY | DONE |

## Interface Contracts

### Simulation ↔ UI (`scripts/sim/world_simulation.gd` ↔ `scripts/ui/god_hud.gd`)
- `signal diplomacy_relation_changed(city_a_id: int, city_b_id: int, old_status: String, new_status: String)`
- `signal dyson_megastructure_stage_advanced(stage_index: int, stage_name: String, total_energy: float)`
- `signal building_damaged_or_destroyed(city_id: int, building_id: String, is_destroyed: bool)`
- `signal actor_damaged_or_killed(actor_id: int, killer_id: int, cause: String)`
- `signal world_constant_modified(constant_id: String, new_value: float)`
- `get_detailed_city_data(city_id: int) -> Dictionary`
- `get_detailed_actor_data(actor_id: int) -> Dictionary`
- `get_global_world_metrics() -> Dictionary`

### Simulation ↔ Audio (`scripts/sim/world_simulation.gd` ↔ `scripts/audio/audio_subsystem.gd`)
- `signal sfx_requested(sfx_id: String, world_pos: Vector2, pitch_scale: float, volume_db: float)`
- `signal ambient_state_changed(ambient_mood: String, intensity: float)`

### Simulation ↔ Renderer (`scripts/sim/world_simulation.gd` ↔ `scripts/render/cosmic_renderer.gd`)
- `signal dyson_visual_state_updated(stage: int, progress: float, active_segments: int)`
- `signal shockwave_triggered(world_pos: Vector2, radius: float, color: Color)`
- `request_dirty_rect_update(rect: Rect2i)`

## Code Layout
- `scenes/`: Godot scenes (`main.tscn`)
- `scripts/core/`: Asset declarations and data structures (`asset_manager.gd`, `sandbox_asset.gd`)
- `scripts/sim/`: Core simulation logic (`world_simulation.gd`, diplomacy, megastructures)
- `scripts/render/`: 2D rendering, camera, visual effects (`cosmic_renderer.gd`, `orbit_camera.gd`)
- `scripts/audio/`: Sound bus management, procedural audio, SFX playback (`audio_subsystem.gd`)
- `scripts/ui/`: God HUD, modal inspectors, analytics charts (`god_hud.gd`)
- `shaders/`: 2D CanvasItem shaders (`dyson_aura.gdshader`, `cosmic_lens.gdshader`, `worldbox_multimesh.gdshader`)
- `tests/`: Automated headless test suites executed via `run_all_tests.ps1` and `run_test_safe.ps1` (`test_step1_registry.gd`, `test_step2_simulation.gd`, `test_sandbox_suite.gd`, etc.)
