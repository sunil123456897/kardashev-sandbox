# AGENTS.md — Kardashev Sandbox: Crucible of Stars (Godot 4.7.2)

Architecture & feature contracts: see [`PROJECT.md`](PROJECT.md).
2D Pixel-Art WorldBox patterns: load skill `godot-2d-pixel-sandbox`.

## Commands (PowerShell)

- **Single test suite (15s watchdog)**:
  `powershell -NoProfile -ExecutionPolicy Bypass -File "run_test_safe.ps1" -ScriptPath "tests/<test_name>.gd" -TimeoutMs 15000`
- **All 11 core E2E suites (~19s)**:
  `powershell -NoProfile -ExecutionPolicy Bypass -File "run_all_tests.ps1" -CoreOnly`
- **Filter suites by wildcard**:
  `powershell -NoProfile -ExecutionPolicy Bypass -File "run_all_tests.ps1" -Filter "*authentic*"`
- **Capture GPU screenshots (`screenshots/shot_1..6.png`, non-headless with 15s watchdog)**:
  ```powershell
  $godot = (Resolve-Path "C:\Users\vanya\Desktop\*\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe").Path
  $proj = (Resolve-Path "E:\Godot*\1").Path
  $p = Start-Process -FilePath $godot -ArgumentList @("--path", $proj, "-s", "tests/capture_verification_shots.gd") -PassThru -WindowStyle Hidden
  if (-not $p.WaitForExit(15000)) { $p.Kill(); throw "Screenshot capture timed out" }
  ```

## Test Invariants (Do Not Break)

1. **`scripts/core/asset_manager.gd`** (`tests/test_step1_registry.gd`):
   Exact list sizes: `biome_list == 8`, `subspecies_trait_list == 22`, `culture_trait_list == 12`, `build_order_list == 9`, `plot_list == 8`, `god_power_list == 20`, `world_law_list == 6`, `world_behaviour_list == 6`.
2. **`scripts/render/cosmic_renderer.gd`** (`tests/test_worldbox_overhaul.gd`):
   Horizontal sprite atlas sizes: `_atlas_flora_tex` (`100×10`), `_atlas_building_tex` (`96×12`), `_atlas_actor_tex` (`100×10`).
3. **`scripts/sim/world_simulation.gd`** (`tests/test_milestone4_performance_and_stability.gd` & `tests/test_milestone3_audiovisuals_and_ui.gd`):
   - `step_simulation(dt)` must advance `world_year += dt * 2.5`; tune real-time gameplay speed only via `realtime_pace_scale` in `_process(delta)`.
   - Starter cities must initialize with `kardashev_level >= 0.50`.
   - `release_divine_magnet(drop_pos: Vector2 = Vector2(-1.0, -1.0))` must keep its default argument so both 0-arg and 1-arg callers succeed.

## Monolith Section Index

- **`scripts/sim/world_simulation.gd` (5,422 lines)**:
  - `L1–L540`: Constants, state dictionaries, `setup_world()`, `_build_2d_worldbox_grid()`
  - `L545–L965`: `_populate_fine_flora_and_minerals()`, `sample_fine_world_tile()`, `_get_zone_owner()`, `_carve_city_roads_and_fields()`, `_seed_initial_cradle()`
  - `L970–L1110`: `_process(delta)`, `step_simulation(dt)`, `_substep_simulation(sub_dt)`, `_execute_world_behaviour()`
  - `L1112–L1770`: `_spawn_actor_unit()`, `_step_actors(dt)` (`run_to_water_when_on_fire` at `L1340`), `_assign_next_citizen_job_target()`, `_step_actor_combat()`, `_tick_world_ages()`
  - `L1775–L2660`: `_tick_thermodynamics_and_lenses()`, `_tick_biome_spread_and_abiogenesis()`, `_tick_subspecies_evolution()`, `_uplift_subspecies_and_found_city()`, `_tick_city_build_orders()`, `_tick_plots_and_infinite_science()`
  - `L2665–L4580`: `_tick_dyson_swarm_and_star()`, `apply_god_power_at_pos()`, diplomacy, wars, trade, inspection getters, serialization (`export_world_save_dict` / `import_world_save_dict`)
  - `L4585–L5422`: Boats (`_step_boats`), projectiles (`_step_projectiles`), needs/status/socialize (`_step_actor_status_effects_and_needs`), kingdoms/loyalty, religions/languages/books, chromosomes, xeno-biomass, possession (`step_controlled_actor`)
- **`scripts/render/cosmic_renderer.gd` (1,959 lines)**:
  - `L200–L370`: `_init_multimeshes()`, `_update_multimeshes(delta)`
  - `L605–L893`: Dirty-rect map texture (`_sample_and_shade_pixel` at `L685`, `compute_non_overlapping_city_banner_rects` at `L847`)
  - `L898–L1650`: `_draw_mode_planet_worldbox()` (bonfires/windmills at `L928`, actors/items/speech bubbles at `L980`), `_draw_mode_star_dyson_2d()`, `_draw_mode_system_overview_2d()`
  - `L1655–L1959`: `_build_pixel_art_sprites()` (procedural pixel-art sprite tables)
- **`scripts/ui/god_hud.gd` (2,009 lines)**:
  - `L83–L430`: `setup()`, `toggle_side_panels()`, `_build_ui_tree()` (top bar, collapsible left/right panels, bottom WorldBox dock)
  - `L435–L1260`: Modals (`_build_codex_modal`, `_build_laws_modal`, `_build_city_inspector_modal`, `_build_actor_inspector_modal`, `_build_culture_inspector_modal`, `_build_analytics_modal`, `_build_world_modal`)
  - `L1265–L2009`: Inspector population (`_populate_city_inspector`, `_populate_actor_inspector`, `_populate_world_modal`) & event log filtering
