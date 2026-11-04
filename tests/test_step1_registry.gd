extends SceneTree

const SandboxAssetManager = preload("res://scripts/core/asset_manager.gd")

func _init() -> void:
	var am := SandboxAssetManager.new()
	print("=== STEP 1 REGISTRY VERIFICATION ===")
	print("Biomes count: ", am.biome_list.size())
	print("Subspecies traits count: ", am.subspecies_trait_list.size())
	print("Culture traits count: ", am.culture_trait_list.size())
	print("Build orders count: ", am.build_order_list.size())
	print("Plots count: ", am.plot_list.size())
	print("God powers count: ", am.god_power_list.size())
	print("World laws count: ", am.world_law_list.size())
	print("World behaviours count: ", am.world_behaviour_list.size())

	assert(am.biome_list.size() == 8, "Expected 8 biomes")
	assert(am.subspecies_trait_list.size() == 22, "Expected 22 subspecies traits")
	assert(am.culture_trait_list.size() == 12, "Expected 12 culture traits")
	assert(am.build_order_list.size() == 9, "Expected 9 build orders")
	assert(am.plot_list.size() == 8, "Expected 8 plots")
	assert(am.god_power_list.size() == 20, "Expected 20 god powers")
	assert(am.world_law_list.size() == 6, "Expected 6 world laws")
	assert(am.world_behaviour_list.size() == 6, "Expected 6 world behaviours")

	# Check cross-references
	for p in am.plot_list:
		if p.reward_culture_trait != "":
			assert(am.culture_traits.has(p.reward_culture_trait), "Missing culture trait: " + p.reward_culture_trait)
		if p.reward_god_power_id != "":
			assert(am.god_powers.has(p.reward_god_power_id), "Missing god power: " + p.reward_god_power_id)

	for b in am.biome_list:
		for st in b.spawn_trait_subspecies:
			assert(am.subspecies_traits.has(st), "Missing spawn subspecies trait: " + st)
		for et in b.evolution_trait_subspecies:
			assert(am.subspecies_traits.has(et), "Missing evolution subspecies trait: " + et)
		for ct in b.spawn_trait_culture:
			assert(am.culture_traits.has(ct), "Missing spawn culture trait: " + ct)

	print("STEP 1 REGISTRY VERIFICATION: ALL ASSERTIONS PASSED!")
	quit(0)
