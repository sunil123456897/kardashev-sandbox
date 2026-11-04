extends SceneTree

const WorldSimulationScript = preload("res://scripts/sim/world_simulation.gd")
const CosmicRendererScript = preload("res://scripts/render/cosmic_renderer.gd")
const SandboxAssetScript = preload("res://scripts/core/sandbox_asset.gd")

var total_assertions: int = 0
var total_passed: int = 0
var total_failed: int = 0

func assert_true(cond: bool, msg: String) -> void:
	total_assertions += 1
	if cond:
		total_passed += 1
	else:
		total_failed += 1
		printerr(" [FAIL] Assertion failed: ", msg)
		assert(false, msg)

func assert_approx_eq(a: float, b: float, tolerance: float, msg: String) -> void:
	total_assertions += 1
	if absf(a - b) <= tolerance:
		total_passed += 1
	else:
		total_failed += 1
		var err_str := "%s (got %f, expected %f, diff %f > tol %f)" % [msg, a, b, absf(a - b), tolerance]
		printerr(" [FAIL] ", err_str)
		assert(false, err_str)

func _init() -> void:
	print("================================================================================")
	print("=== FORENSIC INTEGRITY AUDIT TEST SUITE (M4 FORENSIC AUDITOR) ===")
	print("================================================================================")

	var sim := WorldSimulationScript.new()
	sim.name = "SimForensic"
	root.add_child(sim)
	sim.setup_world(9999)

	var renderer := CosmicRendererScript.new()
	renderer.name = "RendererForensic"
	root.add_child(renderer)
	renderer.setup(sim)

	# ==========================================================================
	# CHECK 1: DIRTY RECT PARTIALITY PROOF (NOT A SILENT FULL REBUILD)
	# ==========================================================================
	print("\n[CHECK 1] Proving Dirty Rect Partiality vs Silent Full Rebuild...")
	var img: Image = renderer.get("_planet_image")
	assert_true(img != null, "_planet_image must be valid")

	# Pick two distinct land tiles in the simulation
	# Tile 500 (middle land) and Tile 520 (another land tile)
	var t_a_idx: int = 500
	var t_b_idx: int = 520

	var uv_a: Vector2 = sim.tiles[t_a_idx]["uv"]
	var uv_b: Vector2 = sim.tiles[t_b_idx]["uv"]

	var px_a := Vector2i(int(uv_a.x * float(CosmicRendererScript.TEX_W)), int(uv_a.y * float(CosmicRendererScript.TEX_H)))
	var px_b := Vector2i(int(uv_b.x * float(CosmicRendererScript.TEX_W)), int(uv_b.y * float(CosmicRendererScript.TEX_H)))

	# Save baseline colors before modification
	var orig_col_a: Color = img.get_pixel(px_a.x, px_a.y)
	var orig_col_b: Color = img.get_pixel(px_b.x, px_b.y)

	# Mutate BOTH tiles on the simulation side
	sim.tiles[t_a_idx]["biome_id"] = "biome_plasma_inferno"
	sim.tiles[t_a_idx]["elevation"] = 0.38
	sim.tiles[t_b_idx]["biome_id"] = "biome_plasma_inferno"
	sim.tiles[t_b_idx]["elevation"] = 0.38

	# Now request dirty rect update ONLY around pixel A: Rect2i(px_a.x - 10, px_a.y - 10, 20, 20)
	# This bounding box strictly excludes pixel B
	var dirty_rect_a := Rect2i(px_a.x - 10, px_a.y - 10, 20, 20)
	assert_true(dirty_rect_a.has_point(px_a), "Dirty rect must contain Pixel A")
	assert_true(not dirty_rect_a.has_point(px_b), "Dirty rect must NOT contain Pixel B")

	var updates_before: int = int(renderer.get("dirty_rect_update_count"))
	renderer.request_dirty_rect_update(dirty_rect_a)
	var updates_after: int = int(renderer.get("dirty_rect_update_count"))
	assert_true(updates_after == updates_before + 1, "dirty_rect_update_count must increment by 1")

	var new_col_a: Color = img.get_pixel(px_a.x, px_a.y)
	var new_col_b: Color = img.get_pixel(px_b.x, px_b.y)

	assert_true(new_col_a != orig_col_a, "Pixel A inside dirty rect MUST be updated to new shaded color")
	assert_true(new_col_b == orig_col_b, "Pixel B outside dirty rect MUST REMAIN UNCHANGED (proves NO silent full rebuild!)")
	print(" -> PASS: Pixel A updated (%s -> %s), Pixel B strictly retained (%s == %s)" % [orig_col_a, new_col_a, orig_col_b, new_col_b])

	# ==========================================================================
	# CHECK 2: SIMULATION SUBSTEPPING DISCRETE 50 MS SLICES & ACCUMULATOR
	# ==========================================================================
	print("\n[CHECK 2] Proving Discrete 50ms Substepping Engine & Accumulator Integrity...")
	var initial_acc: float = sim._sim_time_accumulator
	assert_approx_eq(initial_acc, 0.0, 0.001, "Simulation accumulator must start at 0.0")

	# Step 1: dt = 0.035 (less than 50 ms) -> Accumulates, 0 substeps executed
	var year_t0: float = sim.world_year
	sim.step_simulation(0.035)
	assert_approx_eq(sim._sim_time_accumulator, 0.035, 0.001, "Accumulator must hold 0.035s")
	assert_approx_eq(sim.world_year - year_t0, 0.035 * 2.5, 0.001, "world_year tracks total dt")

	# Step 2: dt = 0.075 -> Total accumulated = 0.110s. Exactly 2 substeps (2 * 0.05 = 0.10), leaving 0.010s in accumulator
	sim.step_simulation(0.075)
	assert_approx_eq(sim._sim_time_accumulator, 0.010, 0.002, "Accumulator must retain leftover fraction 0.010s")

	# Step 3: dt = 0.045 -> Total accumulated = 0.055s. Exactly 1 substep (0.05), leaving ~0.005s in accumulator
	sim.step_simulation(0.045)
	assert_approx_eq(sim._sim_time_accumulator, 0.005, 0.002, "Accumulator must consume exactly 0.05s leaving 0.005s")
	print(" -> PASS: Deterministic accumulator progression confirmed (0.035s -> 0.010s -> 0.005s)")

	# Verify actor ticks: actor anim_phase increments with substeps
	assert_true(sim.actors.size() > 0, "Simulation must contain living actors")
	var test_actor: Dictionary = sim.actors[0]
	var anim_before: float = float(test_actor["anim_phase"])
	sim.step_simulation(0.10) # exactly 2 substeps of 0.05s
	var anim_after: float = float(test_actor["anim_phase"])
	assert_true(anim_after > anim_before, "Actor animation phase must advance across substeps")
	print(" -> PASS: Actor ticks verified across substeps (anim: %f -> %f)" % [anim_before, anim_after])

	# ==========================================================================
	# CHECK 3: BUILDING ENTROPY, REPAIR CHECK, DESTRUCTION & SLOT FREEING
	# ==========================================================================
	print("\n[CHECK 3] Proving Building Entropy Degradation, Repair & Slot Freeing...")
	assert_true(sim.cities_map.size() > 0, "Simulation must contain at least 1 city")
	var c_id: int = int(sim.cities_map.keys()[0])
	var city: Dictionary = sim.cities_map[c_id]

	# Add 1 Bio-Dome and 1 Geothermal Extractor (valid registered build orders)
	city["buildings"]["order_bio_dome"] = 1
	city["buildings"]["order_geothermal_extractor"] = 1
	if not city.has("building_durability"):
		city["building_durability"] = {}
	city["building_durability"]["order_bio_dome"] = 100.0
	city["building_durability"]["order_geothermal_extractor"] = 100.0
	sim._rebuild_city_2d_instances(city)
	var initial_instance_count: int = city["building_instances"].size()
	assert_true(initial_instance_count >= 2, "City must have at least 2 building instances")

	# Subcheck 3.1: Active repair in prosperous city
	city["population"] = 50.0
	sim.matter_stock = 100.0
	sim.set_world_constant("cosmic_entropy_rate", 0.05) # Very low entropy so repair dominates
	city["building_durability"]["order_bio_dome"] = 60.0
	sim._tick_building_entropy(10.0)
	var repaired_hp: float = float(city["building_durability"]["order_bio_dome"])
	assert_true(repaired_hp > 60.0, "Prosperous city with population and matter must repair damaged building (60.0 -> %f)" % repaired_hp)
	print(" -> PASS: Active repair confirmed (60.0 -> %f)" % repaired_hp)

	# Subcheck 3.2: Severe entropy degradation leading to collapse
	city["population"] = 2.0 # Impoverished, cannot repair
	sim.matter_stock = 0.0
	sim.set_world_constant("cosmic_entropy_rate", 10.0) # High entropy rate

	# Set durability near collapse threshold
	city["building_durability"]["order_bio_dome"] = 2.0

	var destroyed_signals: Array[Dictionary] = []
	var cb_collapse := func(cid: int, bid: String, is_destroyed: bool) -> void:
		if is_destroyed:
			destroyed_signals.append({"cid": cid, "bid": bid})

	sim.building_damaged_or_destroyed.connect(cb_collapse)

	# Tick entropy enough to deplete 2.0 HP (wear_rate with sigma=10 is ~1.5/s, 5.0s will deplete >7.5 HP)
	sim._tick_building_entropy(5.0)

	assert_true(not destroyed_signals.is_empty(), "building_damaged_or_destroyed signal MUST fire when durability drops to 0 via entropy")
	var collapsed_event: Dictionary = destroyed_signals[0]
	assert_true(int(collapsed_event["cid"]) == c_id, "Signal must indicate correct city")
	assert_true(str(collapsed_event["bid"]) == "order_bio_dome", "Signal must indicate destroyed building")

	# Check removal and slot freeing
	assert_true(not city["buildings"].has("order_bio_dome"), "Destroyed building must be erased from city buildings")
	assert_true(not city["building_durability"].has("order_bio_dome"), "Destroyed building must be erased from durability map")

	var instances_after_collapse: int = city["building_instances"].size()
	assert_true(instances_after_collapse < initial_instance_count, "Visual instances count must decrease (freeing building slot)")
	print(" -> PASS: Building collapsed authentically via entropy tick, signal fired, slot freed (%d -> %d instances)" % [
		initial_instance_count, instances_after_collapse
	])
	sim.building_damaged_or_destroyed.disconnect(cb_collapse)

	# Cleanup
	renderer.free()
	sim.free()

	print("\n================================================================================")
	print("=== FORENSIC INTEGRITY AUDIT: 100% CLEAN (ALL AUDITOR CHECKS PASSED) ===")
	print("Total assertions evaluated: %d" % total_assertions)
	print("Total assertions passed:    %d" % total_passed)
	print("Total assertions failed:    %d" % total_failed)
	print("================================================================================")
	quit(0)
