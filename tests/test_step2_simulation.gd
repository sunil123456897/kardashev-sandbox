extends SceneTree

const WorldSimulationScript = preload("res://scripts/sim/world_simulation.gd")

func _init() -> void:
	print("=== STEP 2 SIMULATION ENGINE (2D WORLDBOX GRID + ACTORS) VERIFICATION ===")
	var sim := WorldSimulationScript.new()
	sim.setup_world(42)

	assert(sim.tiles.size() == 1024, "Expected 1024 2D grid tiles (32x32)")
	assert(sim.subspecies_map.size() >= 2, "Expected at least 2 initial subspecies")
	assert(sim.cities_map.size() >= 2, "Expected at least 2 initial cities")
	assert(sim.actors.size() >= 15, "Expected living 2D pixel actors on map")
	assert(sim.dyson_rings.size() >= 1, "Expected initial dyson ring")

	# Test 2D God Powers: Alchemy, Life, Lenses, Cosmos
	var r1 := sim.apply_god_power_at_pos(Vector2(650, 480), "power_actinide_meteor", 0.25)
	assert(bool(r1["ok"]), "Actinide meteor failed")

	var r2 := sim.apply_god_power_at_pos(Vector2(1150, 520), "power_seed_plasma")
	assert(bool(r2["ok"]) and int(r2["subspecies_id"]) > 0, "Spawn plasma life failed")

	var r3 := sim.apply_god_power_at_pos(Vector2(1150, 520), "power_monolith_uplift")
	assert(bool(r3["ok"]) and int(r3["city_id"]) > 0, "Monolith uplift failed")

	var r4 := sim.apply_god_power_at_pos(Vector2(1150, 520), "power_lens_time_accel", 0.32)
	assert(bool(r4["ok"]) and sim.field_lenses.size() >= 1, "Time lens placement failed")

	# Step simulation forward to trigger BuildOrders, Plots, Actor movement, and Infinite Science
	for _i in range(40):
		sim.step_simulation(1.0)

	print("Cities count after sim: ", sim.cities_map.size())
	print("Living 2D Actors count: ", sim.actors.size())
	print("Active plots count: ", sim.active_plots.size())
	print("Codex theories count: ", sim.codex_theories.size())
	print("Total Dyson sails: ", sim.total_dyson_sails)
	print("Max Kardashev level: %.2f" % sim.get_max_kardashev_level())

	assert(sim.codex_theories.size() >= 1, "Expected at least 1 synthesized infinite theory")
	assert(sim.total_dyson_sails > 24, "Expected Dyson swarm growth")

	var prev_theories: int = sim.codex_theories.size()
	sim.apply_god_power_at_pos(Vector2(960, 540), "power_chrono_supernova")
	assert(sim.chrono_cycle == 2, "Expected chrono_cycle == 2 after supernova")
	assert(sim.codex_theories.size() >= prev_theories, "Codex theories must persist across supernova loop")

	sim.free()
	print("STEP 2 SIMULATION ENGINE VERIFICATION: ALL ASSERTIONS PASSED!")
	quit(0)
