class_name SandboxAsset
extends RefCounted

## Базовые структуры карточек данных (по образцу Asset / AssetLibrary<T> из WorldBox v0.51.2).
## Позволяют декларативно описывать биомы, генетические черты, научные парадигмы,
## цепочки авто-строительства (BuildOrder), глобальные замыслы (PlotAsset),
## божественные силы (GodPower) и законы мира (WorldLawAsset).

var id: String = ""
var title: String = ""
var description: String = ""
var category: String = ""
var icon_symbol: String = "*"
var color: Color = Color.WHITE
var index_id: int = 0


class BiomeAsset extends SandboxAsset:
	var base_color_low: Color = Color(0.12, 0.16, 0.22)
	var base_color_high: Color = Color(0.22, 0.28, 0.36)
	var edge_color: Color = Color(0.10, 0.14, 0.18)
	var decor_color: Color = Color(0.35, 0.48, 0.30)
	var emissive_color: Color = Color(0.0, 0.0, 0.0)
	var emissive_strength: float = 0.0
	var ideal_temp_c: float = 15.0
	var radiation_level: float = 0.05
	var gravity_mod: float = 1.0
	var time_scale_mod: float = 1.0
	var matter_yield: float = 1.0
	var energy_yield: float = 1.0
	var compute_yield: float = 1.0
	var spread_strength: int = 1
	var is_extreme: bool = false
	var spawn_trait_subspecies: Array[String] = []
	var evolution_trait_subspecies: Array[String] = []
	var spawn_trait_culture: Array[String] = []
	var science_tags: Array[String] = []


class SubspeciesTraitAsset extends SandboxAsset:
	var group_id: String = "biology" # biology, cognition, metabolism, adaptation, quantum
	var grants_sapience: bool = false # аналог prefrontal_cortex -> has_sapience из WorldBox
	var pop_growth_mult: float = 1.0
	var intelligence_bonus: float = 0.0
	var energy_output_mult: float = 1.0
	var compute_output_mult: float = 1.0
	var hazard_resistance: float = 0.0
	var preferred_biome_id: String = ""
	var opposite_traits: Array[String] = []
	var unlocked_science_tags: Array[String] = []


class CultureTraitAsset extends SandboxAsset:
	var group_id: String = "town_plan" # town_plan, paradigm, governance, ascension
	var town_layout_plan: String = ""  # rings, honeycomb, monolith_mesh, fractal, spiral
	var science_speed_mult: float = 1.0
	var build_speed_mult: float = 1.0
	var dyson_swarm_efficiency: float = 1.0
	var kardashev_tier_req: float = 0.5
	var unlocked_god_power_id: String = ""
	var science_tags: Array[String] = []


class CulturalEthosAsset extends SandboxAsset:
	## Социетальный этос цивилизации (экспансионизм, милитаризм, ксенофилия, сциентизм)
	var opposite_ethos_id: String = ""
	var opinion_same_ethos: float = 30.0
	var opinion_opposite_ethos: float = -40.0
	var expansion_drive: float = 1.0       # Множитель основания колоний и территориальной экспансии
	var military_aggression: float = 1.0   # Множитель частоты военных замыслов и боевой мощи
	var science_focus: float = 1.0         # Множитель прогресса научных замыслов и очков теорий
	var trade_affinity: float = 1.0        # Множитель склонности к торговле и доходности торговых пактов
	var cohesion_stability: float = 1.0    # Устойчивость к внутренним восстаниям и расколу
	var preferred_layout: String = "rings" # Предпочитаемый архетип планировки полиса


class BuildOrderAsset extends SandboxAsset:
	var tier: int = 1
	var required_pop: int = 10
	var required_matter: float = 10.0
	var required_energy: float = 5.0
	var required_science_tier: int = 0
	var required_orders: Array[String] = []
	var max_per_city: int = 3
	var is_orbital: bool = false
	var is_megastructure: bool = false
	var matter_prod: float = 0.0
	var energy_prod: float = 0.0
	var compute_prod: float = 0.0
	var spawns_orbital_drones: int = 0
	var visual_archetype: String = "dome" # dome, extractor, spire, collider, elevator, shipyard, anchor, matrioshka
	var is_colony_expedition: bool = false
	var colony_range_tiles: int = 12


class PlotAsset extends SandboxAsset:
	## Аналог PlotAsset из WorldBox, переосмысленный под Научные Прорывы, Мега-Эксперименты, Кризисы и Дипломатию.
	var min_kardashev: float = 0.6
	var min_intelligence: float = 1.0
	var progress_needed: float = 100.0
	var energy_cost_per_sec: float = 2.0
	var anomaly_risk: float = 0.0 # Вероятность пространственно-временной аварии при провале/перегрузке
	var required_biome_or_tag: String = ""
	var reward_culture_trait: String = ""
	var reward_god_power_id: String = ""
	var spawns_dyson_ring: bool = false
	var triggers_supernova_loop: bool = false
	var plot_type: String = "science_breakthrough" # science_breakthrough, megastructure, genetic_ascension, dangerous_experiment, rebellion, diplomacy_war, diplomacy_peace, diplomacy_alliance, diplomacy_trade
	var diplomacy_type: String = "" # war, peace, alliance, trade
	var target_city_id: int = -1
	var opinion_threshold: float = 0.0
	var required_ethos: String = ""


class GodPowerAsset extends SandboxAsset:
	## Аналог GodPower из PowerLibrary в WorldBox v0.51.2.
	var tab_id: String = "alchemy" # alchemy, life, lenses, cosmos
	var power_type: String = "brush_tile" # brush_tile, spawn_life, uplift_ray, place_lens, cosmic_action
	var default_brush_radius: float = 0.22
	var allow_hold_drag: bool = true
	var target_biome_id: String = ""
	var temp_delta_c: float = 0.0
	var height_delta: float = 0.0
	var radiation_delta: float = 0.0
	var matter_injection: float = 0.0
	var energy_injection: float = 0.0
	var lens_type: String = "" # time_accel, zero_grav, singularity, shield_dome
	var lens_duration: float = 45.0
	var lens_time_mult: float = 1.0
	var lens_grav_mult: float = 1.0
	var species_archetype: String = "" # carbon, silicon, plasma, quantum, cyber
	var unlocked_by_default: bool = true
	var beam_color: Color = Color(0.2, 0.85, 1.0)
	# Расширения Milestone 2: Божественный арсенал и катаклизмы (F5)
	var power_category: String = ""
	var energy_cost: float = 0.0
	var cooldown: float = 0.0
	var destructive: bool = false
	var radius_tiles: float = 1.0
	var base_damage: float = 0.0
	var building_damage: float = 0.0
	var actor_damage: float = 0.0
	var shockwave_radius: float = 0.0
	var shockwave_color: Color = Color.WHITE
	var mutation_chance: float = 0.0
	var is_cataclysm: bool = false
	var is_transmutation: bool = false


class PhysicalConstantAsset extends SandboxAsset:
	## Непрерывная фундаментальная физическая константа вселенной (G, c, σ, μ)
	var min_val: float = 0.01
	var max_val: float = 100.0
	var default_val: float = 1.0
	var current_val: float = 1.0
	var unit: String = ""
	var symbol: String = ""
	var effect_description: String = ""
	# Алиасы для расширенной совместимости
	var value: float = 1.0:
		get:
			return current_val
		set(v):
			current_val = v
	var default_value: float = 1.0:
		get:
			return default_val
		set(v):
			default_val = v
	var min_value: float = 0.01:
		get:
			return min_val
		set(v):
			min_val = v
	var max_value: float = 100.0:
		get:
			return max_val
		set(v):
			max_val = v


class AlchemicalReactionAsset extends SandboxAsset:
	## Мульти-элементная алхимическая реакция (термическая закалка, кристаллический мицелий, магматический разлом)
	var primary_input: String = ""
	var secondary_input: String = ""
	var output_biome_id: String = ""
	var temp_result_c: float = 20.0
	var elevation_delta: float = 0.0
	var radiation_delta: float = 0.0
	var energy_yield: float = 0.0
	var matter_yield: float = 0.0
	var reaction_name: String = ""
	var sfx_id: String = ""


class WorldLawAsset extends SandboxAsset:
	var group_id: String = "simulation"
	var enabled_by_default: bool = true


class WorldBehaviourAsset extends SandboxAsset:
	var interval: float = 1.0
	var stop_when_paused: bool = true


class BaseTileAsset extends SandboxAsset:
	## Базовый уровень рельефа (реверс-инженеринг TileLibrary / TileType из WorldBox v0.51.2).
	var color_hex: String = "#3370CC"
	var edge_color_hex: String = "#2858A4"
	var height_tier: int = 0 # 0=deep_ocean, 1=close_ocean, 2=shallow_waters, 3=sand, 4=soil_low, 5=soil_high, 6=hills, 7=mountains, 8=summit
	var is_liquid: bool = false
	var is_ocean: bool = false
	var can_build: bool = true
	var walk_speed_mult: float = 1.0


class CitizenJobAsset extends SandboxAsset:
	## Профессия и цепочка задач жителя полиса (реверс-инженеринг CitizenJobLibrary + ActorJobLibrary из WorldBox v0.51.2).
	var task_steps: Array[String] = [] # e.g. ["find_tree", "move_to_target", "chop_trees", "carry_to_storage", "end_job"]
	var target_type: String = "flora" # flora, mineral, building_site, road_site, field_tile, enemy
	var produced_resource: String = "wood" # wood, minerals, food, road, building
	var work_duration: float = 1.6
	var tool_sprite: String = "axe" # axe, pickaxe, hammer, hoe, spear, scanner


class PersonalTraitAsset extends SandboxAsset:
	## Личная черта конкретного существа (реверс-инженеринг ActorTraitLibrary из WorldBox v0.51.2).
	var hp_bonus: int = 0
	var damage_bonus: float = 0.0
	var speed_mult: float = 1.0
	var scale_mult: float = 1.0
	var intelligence_bonus: float = 0.0
	var is_immortal: bool = false
	var ignites_fire: bool = false
	var regen_per_sec: float = 0.0


class EquipmentAsset extends SandboxAsset:
	## Экипировка из кузницы полиса (оружие и броня из ItemLibrary / EquipmentAsset в WorldBox v0.51.2).
	var slot: String = "weapon" # weapon, armor
	var tier: int = 1
	var mineral_cost: int = 4
	var wood_cost: int = 2
	var damage_bonus: float = 8.0
	var defense_bonus: float = 0.0
	var hp_bonus: int = 0


class WorldAgeAsset extends SandboxAsset:
	## Космическая Эпоха (реверс-инженеринг EraAsset / EraLibrary из WorldBox v0.51.2).
	var ambient_tint: Color = Color(1.0, 1.0, 1.0, 1.0)
	var temp_offset_c: float = 0.0
	var solar_mult: float = 1.0
	var science_mult: float = 1.0
	var war_aggression_mult: float = 1.0
	var freezes_shallow_water: bool = false
	var sparks_wildfires: bool = false


class StatusEffectAsset extends SandboxAsset:
	## Временный статус-эффект на существе (реверс-инженеринг StatusEffectLibrary из WorldBox v0.51.2).
	var duration: float = 8.0
	var dps: float = 0.0
	var speed_mult: float = 1.0
	var defense_bonus: float = 0.0
	var converts_to_xeno: bool = false


class GeneAsset extends SandboxAsset:
	## Генетический локус хромосомы подвида (реверс-инженеринг Chromosome / GeneAsset из WorldBox v0.51.2).
	var locus_type: String = "alpha"
	var hp_bonus: int = 10
	var speed_mult: float = 1.05
	var intelligence_bonus: float = 0.25
	var fertility_mult: float = 1.10
	var synergy_tag: String = "quantum"




