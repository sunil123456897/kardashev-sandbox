extends SceneTree

# Comprehensive Verification Test Suite for AudioSubsystem (F7)
# Runs under Godot 4.7 headless with dummy audio driver.

const WorldSimulationScript = preload("res://scripts/sim/world_simulation.gd")
const SandboxAssetManagerScript = preload("res://scripts/core/asset_manager.gd")

func _init() -> void:
	print("=== RUNNING FULL AUDIO SUBSYSTEM VERIFICATION (HEADLESS COMPATIBLE) ===")
	
	var runner = Node.new()
	runner.set_script(load("res://tests/audio_verification_node.gd"))
	root.add_child(runner)
