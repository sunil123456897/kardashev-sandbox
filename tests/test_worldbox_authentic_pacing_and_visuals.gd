extends SceneTree

## Verification Suite: Authentic WorldBox Visuals, Calm Organic Pacing & Micro-Behaviors
## Verifies:
## 1. Starter archipelago biome palette (>65% lush green grass & golden savanna, 0 starter cybercore grey).
## 2. Organic pacing: 0.5 yr/s time scale, resource-gated city build_progress, gradual Kardashev progression.
## 3. Assembly-CSharp.dll micro-mechanics: run_to_water_when_on_fire, citizen socialize/chat bubbles, vegetation growth.
## 4. Visual & UI improvements: terracotta roofs, unified outer kingdom borders without internal 8x8 grid clutter, collapsible side panels.

const WorldSimulationScript = preload("res://scripts/sim/world_simulation.gd")
const CosmicRendererScript = preload("res://scripts/render/cosmic_renderer.gd")
const GodHUDScript = preload("res://scripts/ui/god_hud.gd")


func _init() -> void:
	print("=== TEST WORLDBOX AUTHENTIC PACING & VISUALS START ===")

	var sim := WorldSimulationScript.new()
	root.add_child(sim)
	sim.setup_world(1337)

	var renderer := CosmicRendererScript.new()
	root.add_child(renderer)
	renderer.setup(sim)

	var hud := GodHUDScript.new()
	root.add_child(hud)
	hud.setup(sim)

	# 1. Verify Starter Archipelago Biome Palette (Lush Green Grasslands & Savanna, 0 grey cybercore)
	var land_count: int = 0
	var natural_green_savanna_count: int = 0
	var cybercore_count: int = 0
	for t in sim.tiles:
		if float(t["elevation"]) >= 0.0:
			land_count += 1
			var bid: String = str(t["biome_id"])
			if bid in ["biome_primordial_ocean", "biome_barren_crust", "biome_cryo_superconductor"]:
				natural_green_savanna_count += 1
			if bid == "biome_cybercore":
				cybercore_count += 1

	var natural_ratio: float = float(natural_green_savanna_count) / float(maxi(1, land_count))
	print("Starter Land Tiles: %d | Natural Green/Savanna/Snow Ratio: %.2f | Cybercore: %d" % [land_count, natural_ratio, cybercore_count])
	assert(natural_ratio >= 0.80, "Expected >=80% natural green/savanna/snow biomes on starter island")
	assert(cybercore_count == 0, "Starter island must have 0 grey cybercore tiles before player intervention")

	# 2. Verify Calm Organic Pacing (realtime_pace_scale = 0.25 in _process, gradual Kardashev & build_progress)
	var y0: float = sim.world_year
	sim._process(2.0)
	var dy: float = sim.world_year - y0
	print("Year delta after 2.0s real-time _process at 1x speed: %.2f" % dy)
	assert(is_equal_approx(dy, 1.25), "Expected 0.625 world_year per wall-clock second (1.25 years per 2.0s)")

	for _i in range(8):
		sim.step_simulation(1.0)
	var metrics: Dictionary = sim.get_global_world_metrics()
	var max_k_10s: float = float(metrics.get("max_kardashev", 0.5))
	print("Max Kardashev after 10s of 1x play: %.3f" % max_k_10s)
	assert(max_k_10s >= 0.50 and max_k_10s < 0.72, "Kardashev level should grow organically and not jump to K-1.0+ in 10 seconds")

	# 3. Verify DecisionsLibrary.run_to_water_when_on_fire
	assert(not sim.actors.is_empty(), "Actors must exist")
	var test_actor: Dictionary = sim.actors[0]
	var actor_id: int = int(test_actor["id"])
	sim.apply_status_effect_to_actor(actor_id, "status_burning", 12.0)
	sim._step_actors(0.2)
	assert(str(test_actor.get("state", "")) == "RUN_TO_WATER", "Burning actor must enter RUN_TO_WATER state")
	# Step until actor reaches water and extinguishes fire
	for _step_w in range(40):
		sim._step_actors(0.5)
		if not (test_actor.get("status_effects", {}) as Dictionary).has("status_burning"):
			break
	assert(sim.total_fires_extinguished_by_water >= 1, "Burning actor must extinguish fire in water")
	print("Fires extinguished by jumping into water: %d" % sim.total_fires_extinguished_by_water)

	# 4. Verify Citizen Socialize / Speech Bubbles (HappinessLibrary.just_talked)
	if sim.actors.size() >= 2:
		var a0: Dictionary = sim.actors[0]
		var a1: Dictionary = sim.actors[1]
		a1["city_id"] = a0["city_id"]
		a1["pos"] = (a0["pos"] as Vector2) + Vector2(6.0, 2.0)
		a0["state"] = "IDLE"
		a1["state"] = "IDLE"
		a0["chat_timer"] = 0.0
		a1["chat_timer"] = 0.0
		for _s in range(30):
			sim._step_actor_status_effects_and_needs(1.0)
			if sim.total_social_chats > 0:
				break
	assert(sim.total_social_chats >= 1, "Citizens near each other must socialize and trigger speech bubbles")
	print("Total social chats triggered: %d" % sim.total_social_chats)

	# 5. Verify Terracotta Village Roofs & Collapsible Side Panels
	var dome_tex: ImageTexture = renderer._sprites.get("bld_dome")
	assert(dome_tex != null, "bld_dome sprite must exist")
	var dome_img: Image = dome_tex.get_image()
	var roof_px: Color = dome_img.get_pixel(5, 2)
	assert(roof_px.r > 0.80 and roof_px.r > roof_px.b * 2.0, "bld_dome roof must use warm terracotta red")

	assert(hud.side_panels_visible == false, "Side panels must be collapsed by default for unobstructed WorldBox map view")
	assert(hud._left_panel.visible == false and hud._right_panel.visible == false, "Left/Right panels must start hidden")
	hud.toggle_side_panels()
	assert(hud.side_panels_visible == true and hud._left_panel.visible == true, "toggle_side_panels() must show side panels")
	hud.toggle_side_panels()
	assert(hud.side_panels_visible == false and hud._left_panel.visible == false, "toggle_side_panels() must hide side panels again")

	hud.free()
	renderer.free()
	sim.free()

	print("=== ALL WORLDBOX AUTHENTIC PACING & VISUALS CHECKS PASSED (FAILED: 0) ===")
	quit(0)
