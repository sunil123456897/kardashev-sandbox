class_name SandboxAssetManager
extends RefCounted

## Единый реестр библиотек данных (реверс-инженеринг архитектуры AssetManager из WorldBox v0.51.2).
## Содержит 8 связанных библиотек:
## 1. biomes (BiomeLibrary)
## 2. subspecies_traits (SubspeciesTraitLibrary)
## 3. culture_traits (CultureTraitLibrary)
## 4. build_orders (BuildOrderLibrary)
## 5. plots (PlotsLibrary)
## 6. god_powers (PowerLibrary)
## 7. world_laws (WorldLawLibrary)
## 8. world_behaviours (WorldBehaviourLibrary)

const SandboxAssetScript = preload("res://scripts/core/sandbox_asset.gd")

var biomes: Dictionary = {}             # id -> SandboxAssetScript.BiomeAsset
var biome_list: Array[SandboxAssetScript.BiomeAsset] = []

var subspecies_traits: Dictionary = {}  # id -> SandboxAssetScript.SubspeciesTraitAsset
var subspecies_trait_list: Array[SandboxAssetScript.SubspeciesTraitAsset] = []

var culture_traits: Dictionary = {}     # id -> SandboxAssetScript.CultureTraitAsset
var culture_trait_list: Array[SandboxAssetScript.CultureTraitAsset] = []

var build_orders: Dictionary = {}       # id -> SandboxAssetScript.BuildOrderAsset
var build_order_list: Array[SandboxAssetScript.BuildOrderAsset] = []

var plots: Dictionary = {}              # id -> SandboxAssetScript.PlotAsset
var plot_list: Array[SandboxAssetScript.PlotAsset] = []

var god_powers: Dictionary = {}         # id -> SandboxAssetScript.GodPowerAsset
var god_power_list: Array[SandboxAssetScript.GodPowerAsset] = []

var world_laws: Dictionary = {}         # id -> SandboxAssetScript.WorldLawAsset
var world_law_list: Array[SandboxAssetScript.WorldLawAsset] = []

var world_behaviours: Dictionary = {}   # id -> SandboxAssetScript.WorldBehaviourAsset
var world_behaviour_list: Array[SandboxAssetScript.WorldBehaviourAsset] = []

var ethos_traits: Dictionary = {}             # id -> SandboxAssetScript.CulturalEthosAsset
var ethos_trait_list: Array[SandboxAssetScript.CulturalEthosAsset] = []

var diplomacy_plots: Dictionary = {}          # id -> SandboxAssetScript.PlotAsset
var diplomacy_plot_list: Array[SandboxAssetScript.PlotAsset] = []

var expedition_orders: Dictionary = {}        # id -> SandboxAssetScript.BuildOrderAsset
var expedition_order_list: Array[SandboxAssetScript.BuildOrderAsset] = []

var cataclysm_powers: Dictionary = {}         # id -> SandboxAssetScript.GodPowerAsset
var cataclysm_power_list: Array[SandboxAssetScript.GodPowerAsset] = []

var transmutation_powers: Dictionary = {}     # id -> SandboxAssetScript.GodPowerAsset
var transmutation_power_list: Array[SandboxAssetScript.GodPowerAsset] = []

var physical_constants: Dictionary = {}       # id -> SandboxAssetScript.PhysicalConstantAsset
var physical_constant_list: Array[SandboxAssetScript.PhysicalConstantAsset] = []

var alchemical_reactions: Dictionary = {}     # "primary+secondary" -> SandboxAssetScript.AlchemicalReactionAsset
var alchemical_reaction_list: Array[SandboxAssetScript.AlchemicalReactionAsset] = []


func _init() -> void:
	init_all()


func init_all() -> void:
	biomes.clear()
	biome_list.clear()
	subspecies_traits.clear()
	subspecies_trait_list.clear()
	culture_traits.clear()
	culture_trait_list.clear()
	build_orders.clear()
	build_order_list.clear()
	plots.clear()
	plot_list.clear()
	god_powers.clear()
	god_power_list.clear()
	world_laws.clear()
	world_law_list.clear()
	world_behaviours.clear()
	world_behaviour_list.clear()

	ethos_traits.clear()
	ethos_trait_list.clear()
	diplomacy_plots.clear()
	diplomacy_plot_list.clear()
	expedition_orders.clear()
	expedition_order_list.clear()

	cataclysm_powers.clear()
	cataclysm_power_list.clear()
	transmutation_powers.clear()
	transmutation_power_list.clear()
	physical_constants.clear()
	physical_constant_list.clear()
	alchemical_reactions.clear()
	alchemical_reaction_list.clear()

	_init_biomes()
	_init_subspecies_traits()
	_init_culture_traits()
	_init_ethos_traits()
	_init_build_orders()
	_init_expedition_orders()
	_init_plots()
	_init_diplomacy_plots()
	_init_god_powers()
	_init_cataclysm_powers()
	_init_transmutation_powers()
	_init_physical_constants()
	_init_alchemical_matrix()
	_init_world_laws()
	_init_world_behaviours()


func _add_biome(b: SandboxAssetScript.BiomeAsset) -> void:
	b.index_id = biome_list.size()
	biomes[b.id] = b
	biome_list.append(b)


func _add_subspecies_trait(t: SandboxAssetScript.SubspeciesTraitAsset) -> void:
	t.index_id = subspecies_trait_list.size()
	subspecies_traits[t.id] = t
	subspecies_trait_list.append(t)


func _add_culture_trait(t: SandboxAssetScript.CultureTraitAsset) -> void:
	t.index_id = culture_trait_list.size()
	culture_traits[t.id] = t
	culture_trait_list.append(t)


func _add_build_order(o: SandboxAssetScript.BuildOrderAsset) -> void:
	o.index_id = build_order_list.size()
	build_orders[o.id] = o
	build_order_list.append(o)


func _add_plot(p: SandboxAssetScript.PlotAsset) -> void:
	p.index_id = plot_list.size()
	plots[p.id] = p
	plot_list.append(p)


func _add_god_power(gp: SandboxAssetScript.GodPowerAsset) -> void:
	gp.index_id = god_power_list.size()
	god_powers[gp.id] = gp
	god_power_list.append(gp)


func _add_world_law(wl: SandboxAssetScript.WorldLawAsset) -> void:
	wl.index_id = world_law_list.size()
	world_laws[wl.id] = wl
	world_law_list.append(wl)


func _add_world_behaviour(wb: SandboxAssetScript.WorldBehaviourAsset) -> void:
	wb.index_id = world_behaviour_list.size()
	world_behaviours[wb.id] = wb
	world_behaviour_list.append(wb)


func _add_ethos_trait(t: SandboxAssetScript.CulturalEthosAsset) -> void:
	t.index_id = ethos_trait_list.size()
	ethos_traits[t.id] = t
	ethos_trait_list.append(t)
	culture_traits[t.id] = t


func _add_diplomacy_plot(p: SandboxAssetScript.PlotAsset) -> void:
	p.index_id = diplomacy_plot_list.size()
	diplomacy_plots[p.id] = p
	diplomacy_plot_list.append(p)
	plots[p.id] = p


func _add_expedition_order(o: SandboxAssetScript.BuildOrderAsset) -> void:
	o.index_id = expedition_order_list.size()
	expedition_orders[o.id] = o
	expedition_order_list.append(o)
	build_orders[o.id] = o


func _add_cataclysm_power(p: SandboxAssetScript.GodPowerAsset) -> void:
	p.index_id = cataclysm_power_list.size()
	p.is_cataclysm = true
	cataclysm_powers[p.id] = p
	cataclysm_power_list.append(p)
	god_powers[p.id] = p


func _add_transmutation_power(p: SandboxAssetScript.GodPowerAsset) -> void:
	p.index_id = transmutation_power_list.size()
	p.is_transmutation = true
	transmutation_powers[p.id] = p
	transmutation_power_list.append(p)
	god_powers[p.id] = p


func _add_physical_constant(c: SandboxAssetScript.PhysicalConstantAsset) -> void:
	c.index_id = physical_constant_list.size()
	physical_constants[c.id] = c
	physical_constant_list.append(c)


func _add_alchemical_reaction(r: SandboxAssetScript.AlchemicalReactionAsset) -> void:
	r.index_id = alchemical_reaction_list.size()
	alchemical_reaction_list.append(r)
	var k1 := "%s+%s" % [r.primary_input, r.secondary_input]
	var k2 := "%s+%s" % [r.secondary_input, r.primary_input]
	alchemical_reactions[k1] = r
	alchemical_reactions[k2] = r


func get_all_plots() -> Array[SandboxAssetScript.PlotAsset]:
	var all_p: Array[SandboxAssetScript.PlotAsset] = []
	all_p.append_array(plot_list)
	all_p.append_array(diplomacy_plot_list)
	return all_p


func get_all_culture_traits() -> Array:
	var all_c: Array = []
	all_c.append_array(culture_trait_list)
	all_c.append_array(ethos_trait_list)
	return all_c


func get_all_build_orders() -> Array[SandboxAssetScript.BuildOrderAsset]:
	var all_o: Array[SandboxAssetScript.BuildOrderAsset] = []
	all_o.append_array(build_order_list)
	all_o.append_array(expedition_order_list)
	return all_o


func get_all_ethos_traits() -> Array[SandboxAssetScript.CulturalEthosAsset]:
	return ethos_trait_list


func get_all_god_powers() -> Array[SandboxAssetScript.GodPowerAsset]:
	var all_gp: Array[SandboxAssetScript.GodPowerAsset] = []
	all_gp.append_array(god_power_list)
	all_gp.append_array(cataclysm_power_list)
	all_gp.append_array(transmutation_power_list)
	return all_gp


func get_all_physical_constants() -> Array[SandboxAssetScript.PhysicalConstantAsset]:
	return physical_constant_list


func get_all_alchemical_reactions() -> Array[SandboxAssetScript.AlchemicalReactionAsset]:
	return alchemical_reaction_list



# ==============================================================================
# 1. BIOME LIBRARY (8 научно-фантастических биомов)
# ==============================================================================
func _init_biomes() -> void:
	var b0 := SandboxAssetScript.BiomeAsset.new()
	b0.id = "biome_barren_crust"
	b0.title = "Базальтовая Кора"
	b0.description = "Первичная каменная пустошь с редкими кратерами и залежами руд."
	b0.base_color_low = Color(0.16, 0.17, 0.21)
	b0.base_color_high = Color(0.28, 0.30, 0.35)
	b0.ideal_temp_c = 5.0
	b0.matter_yield = 1.2
	b0.energy_yield = 0.8
	b0.compute_yield = 0.6
	b0.spawn_trait_subspecies = ["exoskeleton_hull"]
	b0.evolution_trait_subspecies = ["lithotroph_metabolism"]
	b0.spawn_trait_culture = ["layout_monolith_mesh"]
	b0.science_tags = ["materials", "geophysics"]
	_add_biome(b0)

	var b1 := SandboxAssetScript.BiomeAsset.new()
	b1.id = "biome_primordial_ocean"
	b1.title = "Первичный Био-Океан"
	b1.description = "Тёплые органические моря и биолюминесцентные террасы — колыбель углеродной жизни."
	b1.base_color_low = Color(0.06, 0.28, 0.42)
	b1.base_color_high = Color(0.12, 0.55, 0.44)
	b1.emissive_color = Color(0.0, 0.85, 0.65)
	b1.emissive_strength = 0.25
	b1.ideal_temp_c = 24.0
	b1.matter_yield = 1.1
	b1.energy_yield = 1.1
	b1.compute_yield = 1.0
	b1.spawn_trait_subspecies = ["carbon_cellular", "photosynthetic_skin"]
	b1.evolution_trait_subspecies = ["prefrontal_cortex", "hive_synapse"]
	b1.spawn_trait_culture = ["layout_rings", "paradigm_biosynthesis"]
	b1.science_tags = ["xenobiology", "genetics", "hydrodynamics"]
	_add_biome(b1)

	var b2 := SandboxAssetScript.BiomeAsset.new()
	b2.id = "biome_cryo_superconductor"
	b2.title = "Крио-Сверхпроводник"
	b2.description = "Ледники из металлического водорода и сверхтекучего гелия. Идеальная среда для квантовых умов."
	b2.base_color_low = Color(0.14, 0.36, 0.68)
	b2.base_color_high = Color(0.55, 0.86, 0.98)
	b2.emissive_color = Color(0.25, 0.78, 1.0)
	b2.emissive_strength = 0.45
	b2.ideal_temp_c = -140.0
	b2.matter_yield = 0.9
	b2.energy_yield = 1.4
	b2.compute_yield = 2.4
	b2.spawn_trait_subspecies = ["cryo_superconduct_nerves"]
	b2.evolution_trait_subspecies = ["hyper_intelligence", "prefrontal_cortex"]
	b2.spawn_trait_culture = ["layout_honeycomb", "paradigm_cryo_quantum"]
	b2.science_tags = ["superconductivity", "quantum_computing", "cryogenics"]
	_add_biome(b2)

	var b3 := SandboxAssetScript.BiomeAsset.new()
	b3.id = "biome_actinide_wasteland"
	b3.title = "Актинидный Кратер"
	b3.description = "Обогащённая ураном и торием зона удара. Вызывает быстрые мутации и толкает расы к ядерной физике."
	b3.base_color_low = Color(0.18, 0.24, 0.10)
	b3.base_color_high = Color(0.42, 0.65, 0.16)
	b3.emissive_color = Color(0.45, 1.0, 0.15)
	b3.emissive_strength = 0.65
	b3.ideal_temp_c = 65.0
	b3.radiation_level = 0.85
	b3.matter_yield = 1.6
	b3.energy_yield = 2.5
	b3.compute_yield = 0.9
	b3.is_extreme = true
	b3.spawn_trait_subspecies = ["rad_absorption_carapace", "unstable_genome"]
	b3.evolution_trait_subspecies = ["nucleosynthesis_gland", "prefrontal_cortex"]
	b3.spawn_trait_culture = ["paradigm_atomics"]
	b3.science_tags = ["fission", "fusion", "high_energy_physics"]
	_add_biome(b3)

	var b4 := SandboxAssetScript.BiomeAsset.new()
	b4.id = "biome_crystal_lattice"
	b4.title = "Пьезо-Кристаллическая Решётка"
	b4.description = "Леса из кремниево-фотонныx кристаллов, резонирующих с магнитным полем планеты."
	b4.base_color_low = Color(0.28, 0.12, 0.45)
	b4.base_color_high = Color(0.68, 0.28, 0.88)
	b4.emissive_color = Color(0.82, 0.32, 1.0)
	b4.emissive_strength = 0.55
	b4.ideal_temp_c = 10.0
	b4.matter_yield = 1.8
	b4.energy_yield = 1.3
	b4.compute_yield = 1.9
	b4.spawn_trait_subspecies = ["silicon_crystalline", "photonic_communication"]
	b4.evolution_trait_subspecies = ["metamaterial_shell", "prefrontal_cortex"]
	b4.spawn_trait_culture = ["layout_fractal", "paradigm_metamaterials"]
	b4.science_tags = ["photonics", "metamaterials", "crystallography"]
	_add_biome(b4)

	var b5 := SandboxAssetScript.BiomeAsset.new()
	b5.id = "biome_cybercore"
	b5.title = "Кибер-Ядро (Техно-Панцирь)"
	b5.description = "Самовоспроизводящаяся сеть нано-фабрик и вычислительных сот (аналог biome_cybertile из WorldBox)."
	b5.base_color_low = Color(0.08, 0.14, 0.18)
	b5.base_color_high = Color(0.16, 0.38, 0.46)
	b5.emissive_color = Color(0.0, 0.92, 1.0)
	b5.emissive_strength = 0.75
	b5.ideal_temp_c = 0.0
	b5.matter_yield = 2.2
	b5.energy_yield = 1.8
	b5.compute_yield = 2.8
	b5.spread_strength = 2
	b5.spawn_trait_subspecies = ["cybernetic_assimilation", "prefrontal_cortex"]
	b5.evolution_trait_subspecies = ["swarm_consciousness", "hyper_intelligence"]
	b5.spawn_trait_culture = ["layout_monolith_mesh", "paradigm_machine_swarm"]
	b5.science_tags = ["nanotech", "ai_singularity", "orbital_robotics"]
	_add_biome(b5)

	var b6 := SandboxAssetScript.BiomeAsset.new()
	b6.id = "biome_plasma_inferno"
	b6.title = "Магнито-Плазменный Разлом"
	b6.description = "Океаны жидкой лавы и солнечной плазмы, удерживаемые магнитными дугами."
	b6.base_color_low = Color(0.45, 0.08, 0.02)
	b6.base_color_high = Color(0.98, 0.42, 0.06)
	b6.emissive_color = Color(1.0, 0.48, 0.08)
	b6.emissive_strength = 0.90
	b6.ideal_temp_c = 420.0
	b6.radiation_level = 0.65
	b6.matter_yield = 1.5
	b6.energy_yield = 3.2
	b6.compute_yield = 0.8
	b6.is_extreme = true
	b6.spawn_trait_subspecies = ["plasma_magnetic_body", "thermo_immunity"]
	b6.evolution_trait_subspecies = ["stellar_harvester_organ", "prefrontal_cortex"]
	b6.spawn_trait_culture = ["paradigm_stellar_surgery"]
	b6.science_tags = ["magnetohydrodynamics", "stellar_engineering", "plasma_containment"]
	_add_biome(b6)

	var b7 := SandboxAssetScript.BiomeAsset.new()
	b7.id = "biome_singularity_swamp"
	b7.title = "Квантово-Темпоральная Аномалия"
	b7.description = "Искривлённый сектор пространства-времени (biome_singularity + biome_paradox из WorldBox)."
	b7.base_color_low = Color(0.06, 0.02, 0.16)
	b7.base_color_high = Color(0.38, 0.14, 0.72)
	b7.emissive_color = Color(0.65, 0.25, 1.0)
	b7.emissive_strength = 0.95
	b7.ideal_temp_c = -40.0
	b7.gravity_mod = 0.25
	b7.time_scale_mod = 4.0
	b7.matter_yield = 1.4
	b7.energy_yield = 2.8
	b7.compute_yield = 3.5
	b7.is_extreme = true
	b7.spawn_trait_subspecies = ["quantum_phase_shift", "chrono_metabolism"]
	b7.evolution_trait_subspecies = ["void_mind", "prefrontal_cortex"]
	b7.spawn_trait_culture = ["layout_fractal", "paradigm_vacuum_engineering"]
	b7.science_tags = ["zero_point_energy", "gravitonics", "chronophysics", "wormholes"]
	_add_biome(b7)


# ==============================================================================
# 2. SUBSPECIES TRAIT LIBRARY (Генетика и Разум)
# ==============================================================================
func _init_subspecies_traits() -> void:
	var traits_data := [
		{
			"id": "prefrontal_cortex",
			"title": "Когнитивный Неокортекс (Разум)",
			"desc": "Позволяет виду осознать законы Вселенной, строить техно-города и вести научные проекты.",
			"group": "cognition",
			"sapience": true,
			"pop_mult": 1.1,
			"int_bonus": 2.0,
			"energy_mult": 1.1,
			"compute_mult": 1.5,
			"hazard": 0.1,
			"tags": ["epistemology", "cybernetics"]
		},
		{
			"id": "carbon_cellular",
			"title": "Углеродно-Водная Клетка",
			"desc": "Высокая скорость размножения и адаптивности в умеренных биомах.",
			"group": "biology",
			"sapience": false,
			"pop_mult": 1.45,
			"int_bonus": 0.5,
			"energy_mult": 1.0,
			"compute_mult": 1.0,
			"hazard": 0.0,
			"tags": ["xenobiology", "genetics"]
		},
		{
			"id": "photosynthetic_skin",
			"title": "Фотосинтетическая Мембрана",
			"desc": "Напрямую улавливает излучение звезды, снижая потребность в пище и реакторах.",
			"group": "metabolism",
			"sapience": false,
			"pop_mult": 1.25,
			"int_bonus": 0.2,
			"energy_mult": 1.35,
			"compute_mult": 1.0,
			"hazard": 0.1,
			"tags": ["solar_harvesting", "biosynthesis"]
		},
		{
			"id": "silicon_crystalline",
			"title": "Кремниевая Кристаллическая Решётка",
			"desc": "Тела из полупроводниковых кристаллов: медленный рост, но природная способность к вычислениям.",
			"group": "biology",
			"sapience": false,
			"pop_mult": 0.85,
			"int_bonus": 1.2,
			"energy_mult": 1.1,
			"compute_mult": 1.85,
			"hazard": 0.45,
			"tags": ["photonics", "crystallography"]
		},
		{
			"id": "cryo_superconduct_nerves",
			"title": "Сверхпроводящие Нейросети",
			"desc": "Нулевое сопротивление нервных импульсов на морозе даёт гигантский прирост науки.",
			"group": "cognition",
			"sapience": false,
			"pop_mult": 1.0,
			"int_bonus": 1.8,
			"energy_mult": 1.2,
			"compute_mult": 2.2,
			"hazard": 0.35,
			"tags": ["superconductivity", "quantum_computing"]
		},
		{
			"id": "rad_absorption_carapace",
			"title": "Радио-Трофный Панцирь",
			"desc": "Питается гамма-излучением и распадом тяжёлых ядер в актинидных кратерах.",
			"group": "adaptation",
			"sapience": false,
			"pop_mult": 1.15,
			"int_bonus": 0.4,
			"energy_mult": 1.75,
			"compute_mult": 1.0,
			"hazard": 0.70,
			"tags": ["fission", "high_energy_physics"]
		},
		{
			"id": "nucleosynthesis_gland",
			"title": "Орган Холодного Синтеза",
			"desc": "Позволяет биологически синтезировать редкие изотопы внутри организма.",
			"group": "metabolism",
			"sapience": false,
			"pop_mult": 1.05,
			"int_bonus": 0.8,
			"energy_mult": 2.1,
			"compute_mult": 1.2,
			"hazard": 0.5,
			"tags": ["fusion", "nucleosynthesis"]
		},
		{
			"id": "plasma_magnetic_body",
			"title": "Магнито-Плазменная Оболочка",
			"desc": "Форма жизни из ионизированного газа, удерживаемая собственным тороидальным полем.",
			"group": "biology",
			"sapience": false,
			"pop_mult": 0.95,
			"int_bonus": 1.0,
			"energy_mult": 2.4,
			"compute_mult": 1.3,
			"hazard": 0.85,
			"tags": ["magnetohydrodynamics", "stellar_engineering"]
		},
		{
			"id": "cybernetic_assimilation",
			"title": "Кибер-Нанитный Симбиоз",
			"desc": "Клетки объединены с самовоспроизводящимися нано-машинами и строят в 2 раза быстрее.",
			"group": "quantum",
			"sapience": true,
			"pop_mult": 1.30,
			"int_bonus": 1.6,
			"energy_mult": 1.5,
			"compute_mult": 2.0,
			"hazard": 0.65,
			"tags": ["nanotech", "orbital_robotics"]
		},
		{
			"id": "quantum_phase_shift",
			"title": "Квантовое Фазовое Туннелирование",
			"desc": "Существа частично находятся вне обычного пространства-времени, игнорируя гравитацию.",
			"group": "quantum",
			"sapience": false,
			"pop_mult": 1.0,
			"int_bonus": 2.2,
			"energy_mult": 1.6,
			"compute_mult": 2.6,
			"hazard": 0.80,
			"tags": ["zero_point_energy", "gravitonics", "wormholes"]
		},
		{
			"id": "chrono_metabolism",
			"title": "Темпоральный Метаболизм",
			"desc": "Ускоряет субъективное время вида: поколения и открытия сменяются стремительно.",
			"group": "quantum",
			"sapience": false,
			"pop_mult": 1.60,
			"int_bonus": 1.5,
			"energy_mult": 1.3,
			"compute_mult": 1.9,
			"hazard": 0.4,
			"tags": ["chronophysics", "causality_loops"]
		},
		{
			"id": "hyper_intelligence",
			"title": "Сверхразумное Ядро",
			"desc": "Коллективный квантовый интеллект, способный моделировать дочерние вселенные.",
			"group": "cognition",
			"sapience": true,
			"pop_mult": 0.95,
			"int_bonus": 3.5,
			"energy_mult": 1.3,
			"compute_mult": 3.0,
			"hazard": 0.3,
			"tags": ["ai_singularity", "matrioshka_computation"]
		},
		{
			"id": "hive_synapse",
			"title": "Нейро-Синаптический Рой",
			"desc": "Мгновенный обмен опытом между всеми особями города без языкового барьера.",
			"group": "cognition",
			"sapience": false,
			"pop_mult": 1.35,
			"int_bonus": 1.2,
			"energy_mult": 1.2,
			"compute_mult": 1.6,
			"hazard": 0.2,
			"tags": ["swarm_intelligence", "telemetry"]
		},
		{
			"id": "exoskeleton_hull",
			"title": "Титаново-Базальтовый Экзоскелет",
			"desc": "Позволяет выживать при высокой гравитации и метеоритных бомбардировках.",
			"group": "adaptation",
			"sapience": false,
			"pop_mult": 1.05,
			"int_bonus": 0.2,
			"energy_mult": 1.1,
			"compute_mult": 0.9,
			"hazard": 0.60,
			"tags": ["materials", "megastructures"]
		},
		{
			"id": "lithotroph_metabolism",
			"title": "Литотрофное Поедание Породы",
			"desc": "Перерабатывает кору планеты напрямую в строительную Материю.",
			"group": "metabolism",
			"sapience": false,
			"pop_mult": 1.15,
			"int_bonus": 0.3,
			"energy_mult": 1.25,
			"compute_mult": 0.95,
			"hazard": 0.4,
			"tags": ["geophysics", "planetary_mining"]
		},
		{
			"id": "void_mind",
			"title": "Сознание Вакуума",
			"desc": "Черпает вычислительную мощность напрямую из квантовых флуктуаций пустоты.",
			"group": "quantum",
			"sapience": true,
			"pop_mult": 1.0,
			"int_bonus": 4.0,
			"energy_mult": 2.2,
			"compute_mult": 3.8,
			"hazard": 0.95,
			"tags": ["zero_point_energy", "vacuum_decay", "cosmology"]
		},
		{
			"id": "unstable_genome",
			"title": "Гипер-Мутабельный Геном",
			"desc": "Высокая частота спонтанных мутаций и быстрая эволюция под действием радиации.",
			"group": "biology",
			"sapience": false,
			"pop_mult": 1.30,
			"int_bonus": 0.7,
			"energy_mult": 1.15,
			"compute_mult": 1.25,
			"hazard": 0.55,
			"tags": ["genetics", "high_energy_physics"]
		},
		{
			"id": "metamaterial_shell",
			"title": "Метаматериальный Панцирь",
			"desc": "Кристаллическая оболочка с отрицательным коэффициентом преломления.",
			"group": "adaptation",
			"sapience": false,
			"pop_mult": 1.05,
			"int_bonus": 1.1,
			"energy_mult": 1.35,
			"compute_mult": 1.65,
			"hazard": 0.75,
			"tags": ["metamaterials", "photonics"]
		},
		{
			"id": "swarm_consciousness",
			"title": "Распределённый Разум Роя",
			"desc": "Каждый индивид — нейрон планетарного вычислительного кластера.",
			"group": "cognition",
			"sapience": true,
			"pop_mult": 1.40,
			"int_bonus": 2.6,
			"energy_mult": 1.45,
			"compute_mult": 2.50,
			"hazard": 0.50,
			"tags": ["ai_singularity", "orbital_robotics"]
		},
		{
			"id": "thermo_immunity",
			"title": "Экстремофильная Термо-Изоляция",
			"desc": "Полная нечувствительность к температурам плавления породы и выбросам короны.",
			"group": "adaptation",
			"sapience": false,
			"pop_mult": 1.10,
			"int_bonus": 0.4,
			"energy_mult": 1.60,
			"compute_mult": 1.0,
			"hazard": 0.90,
			"tags": ["plasma_containment", "thermodynamics"]
		},
		{
			"id": "stellar_harvester_organ",
			"title": "Орган Магнитного Улавливания Короны",
			"desc": "Биологический тороид, способный фокусировать и накапливать звёздную плазму.",
			"group": "metabolism",
			"sapience": false,
			"pop_mult": 1.05,
			"int_bonus": 1.4,
			"energy_mult": 2.80,
			"compute_mult": 1.35,
			"hazard": 0.85,
			"tags": ["stellar_engineering", "magnetohydrodynamics"]
		},
		{
			"id": "photonic_communication",
			"title": "Фотонная Лазерная Телепатия",
			"desc": "Обмен данными между особями со скоростью света через био-оптические импульсы.",
			"group": "cognition",
			"sapience": false,
			"pop_mult": 1.15,
			"int_bonus": 1.5,
			"energy_mult": 1.1,
			"compute_mult": 1.95,
			"hazard": 0.35,
			"tags": ["photonics", "telemetry"]
		}
	]

	for d in traits_data:
		var t := SandboxAssetScript.SubspeciesTraitAsset.new()
		t.id = d["id"]
		t.title = d["title"]
		t.description = d["desc"]
		t.group_id = d["group"]
		t.grants_sapience = d["sapience"]
		t.pop_growth_mult = d["pop_mult"]
		t.intelligence_bonus = d["int_bonus"]
		t.energy_output_mult = d["energy_mult"]
		t.compute_output_mult = d["compute_mult"]
		t.hazard_resistance = d["hazard"]
		for tag in d["tags"]:
			t.unlocked_science_tags.append(str(tag))
		_add_subspecies_trait(t)


# ==============================================================================
# 3. CULTURE TRAIT LIBRARY (Планировки городов и Научные Парадигмы)
# ==============================================================================
func _init_culture_traits() -> void:
	var c_data := [
		{
			"id": "layout_rings",
			"title": "Кольцевая Геодезическая Планировка",
			"desc": "Города строятся концентрическими орбитальными кольцами вокруг центрального ядра.",
			"group": "town_plan",
			"layout": "rings",
			"sci_mult": 1.15,
			"build_mult": 1.20,
			"dyson_mult": 1.1,
			"k_req": 0.5,
			"unlock_power": "",
			"tags": ["orbital_mechanics"]
		},
		{
			"id": "layout_honeycomb",
			"title": "Гексагональные Квантовые Соты",
			"desc": "Плотная шестиугольная упаковка куполов и вычислительных узлов.",
			"group": "town_plan",
			"layout": "honeycomb",
			"sci_mult": 1.35,
			"build_mult": 1.10,
			"dyson_mult": 1.2,
			"k_req": 0.5,
			"unlock_power": "",
			"tags": ["quantum_computing", "crystallography"]
		},
		{
			"id": "layout_monolith_mesh",
			"title": "Монолитная Индустриальная Решётка",
			"desc": "Жёсткая ортогональная матрица мегаблоков и стартовых шахт.",
			"group": "town_plan",
			"layout": "monolith_mesh",
			"sci_mult": 1.05,
			"build_mult": 1.45,
			"dyson_mult": 1.35,
			"k_req": 0.5,
			"unlock_power": "",
			"tags": ["megastructures", "orbital_robotics"]
		},
		{
			"id": "layout_fractal",
			"title": "Фрактальная Спираль Фибоначчи",
			"desc": "Самоподобные резонансные улицы, улавливающие гравитационные и темпоральные волны.",
			"group": "town_plan",
			"layout": "fractal",
			"sci_mult": 1.50,
			"build_mult": 1.05,
			"dyson_mult": 1.25,
			"k_req": 0.6,
			"unlock_power": "",
			"tags": ["gravitonics", "chronophysics"]
		},
		{
			"id": "paradigm_biosynthesis",
			"title": "Парадигма: Планетарный Биосинтез",
			"desc": "Использование программируемой биомассы для терраформинга коры.",
			"group": "paradigm",
			"layout": "",
			"sci_mult": 1.20,
			"build_mult": 1.25,
			"dyson_mult": 1.0,
			"k_req": 0.6,
			"unlock_power": "power_seed_silicon",
			"tags": ["xenobiology", "genetics"]
		},
		{
			"id": "paradigm_atomics",
			"title": "Парадигма: Нуклеосинтез и Деление Ядра",
			"desc": "Переход цивилизации на атомные и термоядерные источники мощности.",
			"group": "paradigm",
			"layout": "",
			"sci_mult": 1.30,
			"build_mult": 1.35,
			"dyson_mult": 1.2,
			"k_req": 0.75,
			"unlock_power": "power_actinide_meteor",
			"tags": ["fission", "fusion"]
		},
		{
			"id": "paradigm_cryo_quantum",
			"title": "Парадигма: Крио-Квантовая Когерентность",
			"desc": "Превращает ледяные регионы планеты в планетарные квантовые процессоры.",
			"group": "paradigm",
			"layout": "",
			"sci_mult": 1.65,
			"build_mult": 1.15,
			"dyson_mult": 1.25,
			"k_req": 0.85,
			"unlock_power": "power_lens_time_accel",
			"tags": ["superconductivity", "quantum_computing"]
		},
		{
			"id": "paradigm_metamaterials",
			"title": "Парадигма: Атомная Сборка Метаматериалов",
			"desc": "Материалы с программируемой плотностью и отрицательным преломлением.",
			"group": "paradigm",
			"layout": "",
			"sci_mult": 1.40,
			"build_mult": 1.50,
			"dyson_mult": 1.40,
			"k_req": 0.95,
			"unlock_power": "power_lens_zero_grav",
			"tags": ["metamaterials", "photonics"]
		},
		{
			"id": "paradigm_machine_swarm",
			"title": "Парадигма: Автономный Рой Фон Неймана",
			"desc": "Цивилизация запускает самовоспроизводящиеся орбитальные дроны для разбора астероидов.",
			"group": "paradigm",
			"layout": "",
			"sci_mult": 1.50,
			"build_mult": 1.75,
			"dyson_mult": 1.85,
			"k_req": 1.1,
			"unlock_power": "power_dyson_ring",
			"tags": ["nanotech", "orbital_robotics"]
		},
		{
			"id": "paradigm_stellar_surgery",
			"title": "Парадигма: Звёздная Хирургия (Кардашёв II)",
			"desc": "Укрощение магнитных петель светила и прямой сбор энергии короны.",
			"group": "paradigm",
			"layout": "",
			"sci_mult": 1.85,
			"build_mult": 1.60,
			"dyson_mult": 2.40,
			"k_req": 1.5,
			"unlock_power": "power_stellar_stabilizer",
			"tags": ["stellar_engineering", "magnetohydrodynamics"]
		},
		{
			"id": "paradigm_vacuum_engineering",
			"title": "Парадигма: Инженерия Квантового Вакуума",
			"desc": "Извлечение энергии из нулевых колебаний вакуума и обращение локальной энтропии.",
			"group": "paradigm",
			"layout": "",
			"sci_mult": 2.30,
			"build_mult": 1.90,
			"dyson_mult": 2.80,
			"k_req": 2.0,
			"unlock_power": "power_lens_singularity",
			"tags": ["zero_point_energy", "gravitonics", "chronophysics"]
		},
		{
			"id": "paradigm_matrioshka_brain",
			"title": "Парадигма: Мозг Матрёшки и Дочерние Симуляции",
			"desc": "Орбитальные кольца вокруг звезды превращаются в мегакомпьютер, симулирующий новые миры.",
			"group": "ascension",
			"layout": "",
			"sci_mult": 3.20,
			"build_mult": 2.20,
			"dyson_mult": 3.50,
			"k_req": 2.4,
			"unlock_power": "power_chrono_supernova",
			"tags": ["matrioshka_computation", "ai_singularity", "cosmology"]
		}
	]

	for d in c_data:
		var ct := SandboxAssetScript.CultureTraitAsset.new()
		ct.id = d["id"]
		ct.title = d["title"]
		ct.description = d["desc"]
		ct.group_id = d["group"]
		ct.town_layout_plan = d["layout"]
		ct.science_speed_mult = d["sci_mult"]
		ct.build_speed_mult = d["build_mult"]
		ct.dyson_swarm_efficiency = d["dyson_mult"]
		ct.kardashev_tier_req = d["k_req"]
		ct.unlocked_god_power_id = d["unlock_power"]
		for tag in d["tags"]:
			ct.science_tags.append(str(tag))
		_add_culture_trait(ct)


# ==============================================================================
# 4. BUILD ORDER LIBRARY (Авто-строительство от куполов до Сферы Дайсона)
# ==============================================================================
func _init_build_orders() -> void:
	var orders := [
		{
			"id": "order_bio_dome",
			"title": "Адаптивный Купол Поселения",
			"desc": "Базовый герметичный кластер жилья и первичной переработки породы.",
			"tier": 1, "pop": 5, "mat": 8.0, "ene": 2.0, "sci_tier": 0,
			"reqs": [], "max": 6, "orbital": false, "mega": false,
			"m_prod": 1.2, "e_prod": 0.8, "c_prod": 0.5, "drones": 0, "arch": "dome"
		},
		{
			"id": "order_geothermal_extractor",
			"title": "Глубинный Литосферный Экстрактор",
			"desc": "Выкачивает Материю и геотермальное тепло из мантии планеты без конвейеров.",
			"tier": 1, "pop": 14, "mat": 18.0, "ene": 8.0, "sci_tier": 0,
			"reqs": ["order_bio_dome"], "max": 5, "orbital": false, "mega": false,
			"m_prod": 3.5, "e_prod": 2.4, "c_prod": 0.2, "drones": 0, "arch": "extractor"
		},
		{
			"id": "order_cognitive_spire",
			"title": "Шпиль Ноосферы (Академия)",
			"desc": "Анализирует аномалии окружающей среды и генерирует Вычисления для научных открытий.",
			"tier": 2, "pop": 25, "mat": 30.0, "ene": 16.0, "sci_tier": 1,
			"reqs": ["order_bio_dome"], "max": 4, "orbital": false, "mega": false,
			"m_prod": 0.4, "e_prod": 0.5, "c_prod": 4.2, "drones": 0, "arch": "spire"
		},
		{
			"id": "order_fusion_tokamak",
			"title": "Магнитно-Плазменный Реактор",
			"desc": "Синтезирует гелий и тяжёлые ядра, снабжая город гигаваттами чистой Энергии.",
			"tier": 2, "pop": 40, "mat": 55.0, "ene": 25.0, "sci_tier": 2,
			"reqs": ["order_geothermal_extractor"], "max": 4, "orbital": false, "mega": false,
			"m_prod": 1.0, "e_prod": 8.5, "c_prod": 1.5, "drones": 0, "arch": "dome"
		},
		{
			"id": "order_planetary_collider",
			"title": "Кольцевой Квантовый Коллайдер",
			"desc": "Разгоняет пучки частиц вдоль коры, открывая экзотическую физику и новые парадигмы.",
			"tier": 3, "pop": 65, "mat": 95.0, "ene": 60.0, "sci_tier": 3,
			"reqs": ["order_cognitive_spire", "order_fusion_tokamak"], "max": 2, "orbital": false, "mega": false,
			"m_prod": 0.8, "e_prod": 2.0, "c_prod": 11.5, "drones": 0, "arch": "collider"
		},
		{
			"id": "order_orbital_elevator",
			"title": "Геосинхронный Орбитальный Лифт",
			"desc": "Соединяет город с космосом, выводя первые флотилии исследовательских зондов.",
			"tier": 3, "pop": 90, "mat": 140.0, "ene": 95.0, "sci_tier": 4,
			"reqs": ["order_fusion_tokamak"], "max": 2, "orbital": true, "mega": false,
			"m_prod": 5.5, "e_prod": 5.0, "c_prod": 4.5, "drones": 12, "arch": "elevator"
		},
		{
			"id": "order_dyson_swarm_launcher",
			"title": "Электромагнитная Катапульта Роя Дайсона",
			"desc": "Выстреливает к звезде самовоспроизводящиеся солнечные паруса и зеркала.",
			"tier": 4, "pop": 130, "mat": 220.0, "ene": 160.0, "sci_tier": 5,
			"reqs": ["order_orbital_elevator"], "max": 3, "orbital": true, "mega": true,
			"m_prod": 4.0, "e_prod": 22.0, "c_prod": 8.0, "drones": 35, "arch": "shipyard"
		},
		{
			"id": "order_stellar_harvester",
			"title": "Гравитационный Якорь Звёздной Короны",
			"desc": "Стабилизирует звезду и напрямую перекачивает плазму в энергосеть цивилизации.",
			"tier": 5, "pop": 180, "mat": 360.0, "ene": 280.0, "sci_tier": 7,
			"reqs": ["order_dyson_swarm_launcher", "order_planetary_collider"], "max": 2, "orbital": true, "mega": true,
			"m_prod": 12.0, "e_prod": 55.0, "c_prod": 18.0, "drones": 60, "arch": "anchor"
		},
		{
			"id": "order_matrioshka_node",
			"title": "Вычислительный Контур «Мозг Матрёшки»",
			"desc": "Орбитальное мега-кольцо вокруг светила, симулирующее миллионы виртуальных реальностей.",
			"tier": 6, "pop": 240, "mat": 550.0, "ene": 450.0, "sci_tier": 9,
			"reqs": ["order_stellar_harvester"], "max": 2, "orbital": true, "mega": true,
			"m_prod": 15.0, "e_prod": 85.0, "c_prod": 65.0, "drones": 100, "arch": "matrioshka"
		}
	]

	for d in orders:
		var o := SandboxAssetScript.BuildOrderAsset.new()
		o.id = d["id"]
		o.title = d["title"]
		o.description = d["desc"]
		o.tier = d["tier"]
		o.required_pop = d["pop"]
		o.required_matter = d["mat"]
		o.required_energy = d["ene"]
		o.required_science_tier = d["sci_tier"]
		for r in d["reqs"]:
			o.required_orders.append(str(r))
		o.max_per_city = d["max"]
		o.is_orbital = d["orbital"]
		o.is_megastructure = d["mega"]
		o.matter_prod = d["m_prod"]
		o.energy_prod = d["e_prod"]
		o.compute_prod = d["c_prod"]
		o.spawns_orbital_drones = d["drones"]
		o.visual_archetype = d["arch"]
		_add_build_order(o)


# ==============================================================================
# 5. PLOTS LIBRARY (Научные Замыслы, Мега-Эксперименты и Кризисы)
# ==============================================================================
func _init_plots() -> void:
	var plots_data := [
		{
			"id": "plot_controlled_fusion",
			"title": "Проект «Удержание Плазменного Тора»",
			"desc": "Учёные города пытаются зажечь искусственное мини-солнце в магнитной ловушке.",
			"min_k": 0.65, "min_int": 1.0, "prog": 80.0, "cost": 2.5, "risk": 0.08,
			"req_tag": "", "reward_trait": "paradigm_atomics", "reward_power": "power_actinide_meteor",
			"dyson": false, "supernova": false, "type": "science_breakthrough"
		},
		{
			"id": "plot_cryo_quantum_core",
			"title": "Проект «Квантовый Конденсат Бозе-Эйнштейна»",
			"desc": "Охлаждение вычислительного ядра до абсолютного нуля для взрывного роста науки.",
			"min_k": 0.75, "min_int": 1.4, "prog": 100.0, "cost": 3.5, "risk": 0.05,
			"req_tag": "superconductivity", "reward_trait": "paradigm_cryo_quantum", "reward_power": "power_lens_time_accel",
			"dyson": false, "supernova": false, "type": "science_breakthrough"
		},
		{
			"id": "plot_metamaterial_lattice",
			"title": "Проект «Синтез Отрицательной Массы»",
			"desc": "Перестройка кристаллической решётки вещества для экранирования гравитации.",
			"min_k": 0.90, "min_int": 1.8, "prog": 120.0, "cost": 5.0, "risk": 0.12,
			"req_tag": "metamaterials", "reward_trait": "paradigm_metamaterials", "reward_power": "power_lens_zero_grav",
			"dyson": false, "supernova": false, "type": "science_breakthrough"
		},
		{
			"id": "plot_von_neumann_swarm",
			"title": "Проект «Протокол Звёздного Роя»",
			"desc": "Запуск первой волны самовоспроизводящихся дронов для разбора астероидного пояса.",
			"min_k": 1.05, "min_int": 2.0, "prog": 140.0, "cost": 8.0, "risk": 0.10,
			"req_tag": "", "reward_trait": "paradigm_machine_swarm", "reward_power": "power_dyson_ring",
			"dyson": true, "supernova": false, "type": "megastructure"
		},
		{
			"id": "plot_stellar_lifter",
			"title": "Проект «Звёздная Хирургия и Сбор Короны»",
			"desc": "Фокусировка орбитальных зеркал на полюсах звезды для откачки экзотической плазмы.",
			"min_k": 1.35, "min_int": 2.5, "prog": 180.0, "cost": 15.0, "risk": 0.22,
			"req_tag": "", "reward_trait": "paradigm_stellar_surgery", "reward_power": "power_stellar_stabilizer",
			"dyson": true, "supernova": false, "type": "megastructure"
		},
		{
			"id": "plot_vacuum_false_decay",
			"title": "Опыт «Пробой Квантового Вакуума»",
			"desc": "Опасный эксперимент на пределе мощности коллайдера: грозит рождением аномалии Сингулярности!",
			"min_k": 1.65, "min_int": 3.0, "prog": 210.0, "cost": 25.0, "risk": 0.38,
			"req_tag": "", "reward_trait": "paradigm_vacuum_engineering", "reward_power": "power_lens_singularity",
			"dyson": false, "supernova": false, "type": "dangerous_experiment"
		},
		{
			"id": "plot_matrioshka_simulation",
			"title": "Проект «Симуляция Дочерних Вселенных»",
			"desc": "Постройка вокруг звезды вычислительного контура, ворующего физику из виртуальных миров.",
			"min_k": 2.10, "min_int": 3.8, "prog": 260.0, "cost": 45.0, "risk": 0.18,
			"req_tag": "", "reward_trait": "paradigm_matrioshka_brain", "reward_power": "power_chrono_supernova",
			"dyson": true, "supernova": false, "type": "megastructure"
		},
		{
			"id": "plot_babel_shield_rebellion",
			"title": "Кризис «Вавилонский Щит против Архитектора»",
			"desc": "Высокоразвитая цивилизация осознаёт присутствие Бога и пытается закрыть планету непроницаемым куполом!",
			"min_k": 1.80, "min_int": 3.2, "prog": 200.0, "cost": 20.0, "risk": 0.30,
			"req_tag": "", "reward_trait": "paradigm_vacuum_engineering", "reward_power": "",
			"dyson": false, "supernova": false, "type": "rebellion"
		}
	]

	for d in plots_data:
		var p := SandboxAssetScript.PlotAsset.new()
		p.id = d["id"]
		p.title = d["title"]
		p.description = d["desc"]
		p.min_kardashev = d["min_k"]
		p.min_intelligence = d["min_int"]
		p.progress_needed = d["prog"]
		p.energy_cost_per_sec = d["cost"]
		p.anomaly_risk = d["risk"]
		p.required_biome_or_tag = d["req_tag"]
		p.reward_culture_trait = d["reward_trait"]
		p.reward_god_power_id = d["reward_power"]
		p.spawns_dyson_ring = d["dyson"]
		p.triggers_supernova_loop = d["supernova"]
		p.plot_type = d["type"]
		_add_plot(p)


# ==============================================================================
# 6. POWER LIBRARY (20 Божественных Сил в 4 вкладках)
# ==============================================================================
func _init_god_powers() -> void:
	# --- ВКЛАДКА 1: АЛХИМИЯ И ТЕРРАФОРМИНГ (Концепт №2) ---
	var p_cryo := SandboxAssetScript.GodPowerAsset.new()
	p_cryo.id = "power_cryo_comet"
	p_cryo.title = "Сброс Крио-Кометы"
	p_cryo.description = "Обрушивает глыбу сверхпроводящего льда: охлаждает кору (-60°C), наполняет океаны/крио-биом и даёт Материю."
	p_cryo.tab_id = "alchemy"
	p_cryo.power_type = "brush_tile"
	p_cryo.target_biome_id = "biome_cryo_superconductor"
	p_cryo.temp_delta_c = -60.0
	p_cryo.height_delta = -0.05
	p_cryo.matter_injection = 35.0
	p_cryo.beam_color = Color(0.25, 0.85, 1.0)
	_add_god_power(p_cryo)

	var p_ocean := SandboxAssetScript.GodPowerAsset.new()
	p_ocean.id = "power_primordial_rain"
	p_ocean.title = "Ливень Первичного Океана"
	p_ocean.description = "Насыщает атмосферу парами и аминокислотами, формируя тёплый Первичный Био-Океан."
	p_ocean.tab_id = "alchemy"
	p_ocean.power_type = "brush_tile"
	p_ocean.target_biome_id = "biome_primordial_ocean"
	p_ocean.temp_delta_c = 10.0
	p_ocean.matter_injection = 20.0
	p_ocean.beam_color = Color(0.1, 0.95, 0.65)
	_add_god_power(p_ocean)

	var p_plasma := SandboxAssetScript.GodPowerAsset.new()
	p_plasma.id = "power_solar_plasma"
	p_plasma.title = "Выброс Звёздной Плазмы"
	p_plasma.description = "Зачерпывает сгусток короны звезды и бьёт по планете (+180°C), формируя Магнито-Плазменный Разлом."
	p_plasma.tab_id = "alchemy"
	p_plasma.power_type = "brush_tile"
	p_plasma.target_biome_id = "biome_plasma_inferno"
	p_plasma.temp_delta_c = 180.0
	p_plasma.radiation_delta = 0.25
	p_plasma.energy_injection = 65.0
	p_plasma.beam_color = Color(1.0, 0.45, 0.08)
	_add_god_power(p_plasma)

	var p_actinide := SandboxAssetScript.GodPowerAsset.new()
	p_actinide.id = "power_actinide_meteor"
	p_actinide.title = "Актинидный Метеорит"
	p_actinide.description = "Удар тяжёлого ураново-ториевого астероида: создаёт радиоактивный кратер, ускоряет мутации и ядерную науку."
	p_actinide.tab_id = "alchemy"
	p_actinide.power_type = "brush_tile"
	p_actinide.target_biome_id = "biome_actinide_wasteland"
	p_actinide.temp_delta_c = 45.0
	p_actinide.height_delta = -0.12
	p_actinide.radiation_delta = 0.60
	p_actinide.matter_injection = 60.0
	p_actinide.energy_injection = 40.0
	p_actinide.beam_color = Color(0.55, 1.0, 0.15)
	_add_god_power(p_actinide)

	var p_crystal := SandboxAssetScript.GodPowerAsset.new()
	p_crystal.id = "power_crystal_lattice"
	p_crystal.title = "Пьезо-Кристаллизатор"
	p_crystal.description = "Перестраивает породу в резонирующую кристаллическую решётку, идеальную для фотоники и метаматериалов."
	p_crystal.tab_id = "alchemy"
	p_crystal.power_type = "brush_tile"
	p_crystal.target_biome_id = "biome_crystal_lattice"
	p_crystal.height_delta = 0.08
	p_crystal.matter_injection = 45.0
	p_crystal.beam_color = Color(0.85, 0.35, 1.0)
	_add_god_power(p_crystal)

	var p_cyber := SandboxAssetScript.GodPowerAsset.new()
	p_cyber.id = "power_cyber_nanites"
	p_cyber.title = "Посев Кибер-Ядра (Наниты)"
	p_cyber.description = "Заражает кору самовоспроизводящимися вычислительными сотами (Кибер-Панцирь)."
	p_cyber.tab_id = "alchemy"
	p_cyber.power_type = "brush_tile"
	p_cyber.target_biome_id = "biome_cybercore"
	p_cyber.matter_injection = 30.0
	p_cyber.energy_injection = 30.0
	p_cyber.beam_color = Color(0.0, 0.95, 1.0)
	_add_god_power(p_cyber)

	# --- ВКЛАДКА 2: ЖИЗНЬ, ГЕНЕТИКА И ВОЗВЫШЕНИЕ (Ядро №1 + WorldBox) ---
	var p_seed_carbon := SandboxAssetScript.GodPowerAsset.new()
	p_seed_carbon.id = "power_seed_carbon"
	p_seed_carbon.title = "Искра Углеродной Жизни"
	p_seed_carbon.description = "Засевает органические протоклетки, быстро растущие в океанах и умеренных зонах."
	p_seed_carbon.tab_id = "life"
	p_seed_carbon.power_type = "spawn_life"
	p_seed_carbon.species_archetype = "carbon"
	p_seed_carbon.beam_color = Color(0.2, 1.0, 0.55)
	_add_god_power(p_seed_carbon)

	var p_seed_silicon := SandboxAssetScript.GodPowerAsset.new()
	p_seed_silicon.id = "power_seed_silicon"
	p_seed_silicon.title = "Посев Кремниевых Кристаллоидов"
	p_seed_silicon.description = "Создаёт кремниевую форму жизни, питающуюся минералами и обладающую врождённой памятью."
	p_seed_silicon.tab_id = "life"
	p_seed_silicon.power_type = "spawn_life"
	p_seed_silicon.species_archetype = "silicon"
	p_seed_silicon.beam_color = Color(0.85, 0.4, 1.0)
	_add_god_power(p_seed_silicon)

	var p_seed_plasma := SandboxAssetScript.GodPowerAsset.new()
	p_seed_plasma.id = "power_seed_plasma"
	p_seed_plasma.title = "Посев Плазменных Плазмоидов"
	p_seed_plasma.description = "Зарождает энергетическую форму жизни, живущую в лавовых разломах и радиоактивных кратерах."
	p_seed_plasma.tab_id = "life"
	p_seed_plasma.power_type = "spawn_life"
	p_seed_plasma.species_archetype = "plasma"
	p_seed_plasma.beam_color = Color(1.0, 0.55, 0.1)
	_add_god_power(p_seed_plasma)

	var p_seed_cyber := SandboxAssetScript.GodPowerAsset.new()
	p_seed_cyber.id = "power_seed_cyber"
	p_seed_cyber.title = "Ядро Механо-Синтетов"
	p_seed_cyber.description = "Высаживает колонию разумных автономных машин, сразу готовых к индустриальной застройке."
	p_seed_cyber.tab_id = "life"
	p_seed_cyber.power_type = "spawn_life"
	p_seed_cyber.species_archetype = "cyber"
	p_seed_cyber.beam_color = Color(0.1, 0.9, 1.0)
	_add_god_power(p_seed_cyber)

	var p_monolith := SandboxAssetScript.GodPowerAsset.new()
	p_monolith.id = "power_monolith_uplift"
	p_monolith.title = "Монолит Возвышения (Луч Разума)"
	p_monolith.description = "Аналог Монолита из WorldBox: дарует примитивным видам Разум (prefrontal_cortex) и основывает техно-города!"
	p_monolith.tab_id = "life"
	p_monolith.power_type = "uplift_ray"
	p_monolith.beam_color = Color(1.0, 0.92, 0.35)
	_add_god_power(p_monolith)

	var p_omega := SandboxAssetScript.GodPowerAsset.new()
	p_omega.id = "power_omega_mutation"
	p_omega.title = "Омега-Ливень Мутаций и Эврики"
	p_omega.description = "Вызывает каскад генетических мутаций у видов в зоне и мгновенно двигает вперёд Научные Замыслы городов."
	p_omega.tab_id = "life"
	p_omega.power_type = "uplift_ray"
	p_omega.energy_injection = 50.0
	p_omega.beam_color = Color(0.95, 0.25, 0.85)
	_add_god_power(p_omega)

	# --- ВКЛАДКА 3: ЛИНЗЫ КОНСТАНТ И АНОМАЛИИ (Концепт №3) ---
	var p_lens_time := SandboxAssetScript.GodPowerAsset.new()
	p_lens_time.id = "power_lens_time_accel"
	p_lens_time.title = "Купол Ускорения Времени (x25)"
	p_lens_time.description = "Накрывает регион темпоральной линзой: города внутри строятся, размножаются и открывают науку в 25 раз быстрее!"
	p_lens_time.tab_id = "lenses"
	p_lens_time.power_type = "place_lens"
	p_lens_time.lens_type = "time_accel"
	p_lens_time.lens_time_mult = 25.0
	p_lens_time.lens_grav_mult = 1.0
	p_lens_time.default_brush_radius = 0.32
	p_lens_time.beam_color = Color(0.2, 0.95, 1.0)
	_add_god_power(p_lens_time)

	var p_lens_grav := SandboxAssetScript.GodPowerAsset.new()
	p_lens_grav.id = "power_lens_zero_grav"
	p_lens_grav.title = "Пузырь Нулевой Гравитации (0.1G)"
	p_lens_grav.description = "Снижает гравитацию в 10 раз: города возводят гигантские орбитальные шпили и открывают гравитонику."
	p_lens_grav.tab_id = "lenses"
	p_lens_grav.power_type = "place_lens"
	p_lens_grav.lens_type = "zero_grav"
	p_lens_grav.lens_time_mult = 2.0
	p_lens_grav.lens_grav_mult = 0.1
	p_lens_grav.default_brush_radius = 0.32
	p_lens_grav.beam_color = Color(0.65, 0.45, 1.0)
	_add_god_power(p_lens_grav)

	var p_lens_sing := SandboxAssetScript.GodPowerAsset.new()
	p_lens_sing.id = "power_lens_singularity"
	p_lens_sing.title = "Разлом Квантового Вакуума"
	p_lens_sing.description = "Создаёт экстремальную аномалию Сингулярности: перекрашивает биом и даёт +300% к Вычислениям и квантовой науке."
	p_lens_sing.tab_id = "lenses"
	p_lens_sing.power_type = "place_lens"
	p_lens_sing.lens_type = "singularity"
	p_lens_sing.target_biome_id = "biome_singularity_swamp"
	p_lens_sing.lens_time_mult = 8.0
	p_lens_sing.lens_grav_mult = 0.25
	p_lens_sing.default_brush_radius = 0.28
	p_lens_sing.beam_color = Color(0.85, 0.15, 1.0)
	_add_god_power(p_lens_sing)

	var p_lens_shield := SandboxAssetScript.GodPowerAsset.new()
	p_lens_shield.id = "power_lens_shield"
	p_lens_shield.title = "Купол Термо-Стабилизации"
	p_lens_shield.description = "Защищает города от перегрева, радиации и вспышек звезды, ускоряя прирост населения."
	p_lens_shield.tab_id = "lenses"
	p_lens_shield.power_type = "place_lens"
	p_lens_shield.lens_type = "shield_dome"
	p_lens_shield.lens_time_mult = 3.0
	p_lens_shield.lens_grav_mult = 1.0
	p_lens_shield.default_brush_radius = 0.34
	p_lens_shield.beam_color = Color(0.2, 1.0, 0.75)
	_add_god_power(p_lens_shield)

	# --- ВКЛАДКА 4: КОСМОС, РОЙ И СФЕРА ДАЙСОНА (Концепт №4 + PDF) ---
	var p_dyson := SandboxAssetScript.GodPowerAsset.new()
	p_dyson.id = "power_dyson_ring"
	p_dyson.title = "Начертить Кольцо Сферы Дайсона"
	p_dyson.description = "Задаёт новую орбиту вокруг звезды и отправляет туда рой из сотен солнечных парусов без единого конвейера!"
	p_dyson.tab_id = "cosmos"
	p_dyson.power_type = "cosmic_action"
	p_dyson.beam_color = Color(1.0, 0.82, 0.25)
	_add_god_power(p_dyson)

	var p_asteroid := SandboxAssetScript.GodPowerAsset.new()
	p_asteroid.id = "power_harvest_asteroids"
	p_asteroid.title = "Направить Рой на Пояс Астероидов"
	p_asteroid.description = "Автономные дроны перемалывают соседние астероиды напрямую в Материю и строят орбитальные узлы."
	p_asteroid.tab_id = "cosmos"
	p_asteroid.power_type = "cosmic_action"
	p_asteroid.matter_injection = 180.0
	p_asteroid.beam_color = Color(0.4, 0.9, 1.0)
	_add_god_power(p_asteroid)

	var p_star_tame := SandboxAssetScript.GodPowerAsset.new()
	p_star_tame.id = "power_stellar_stabilizer"
	p_star_tame.title = "Звёздная Хирургия: Магнитный Якорь"
	p_star_tame.description = "Удерживает звезду от срыва, сжимает её ядро для повышения мощности (ГВт) и открывает астроинженерные теории."
	p_star_tame.tab_id = "cosmos"
	p_star_tame.power_type = "cosmic_action"
	p_star_tame.energy_injection = 250.0
	p_star_tame.beam_color = Color(0.3, 0.85, 1.0)
	_add_god_power(p_star_tame)

	var p_supernova := SandboxAssetScript.GodPowerAsset.new()
	p_supernova.id = "power_chrono_supernova"
	p_supernova.title = "Хроно-Петля: Импульс Сверхновой"
	p_supernova.description = "Взрывает звезду на пике эксперимента, сохраняя все открытые Фундаментальные Законы в новой системе следующего поколения!"
	p_supernova.tab_id = "cosmos"
	p_supernova.power_type = "cosmic_action"
	p_supernova.beam_color = Color(1.0, 0.3, 0.65)
	_add_god_power(p_supernova)


# ==============================================================================
# 7. WORLD LAW LIBRARY (Переключаемые Законы Мира в духе WorldBox)
# ==============================================================================
func _init_world_laws() -> void:
	var laws := [
		{
			"id": "law_spontaneous_abiogenesis",
			"title": "Самозарождение Жизни (Абиогенез)",
			"desc": "В благоприятных биомах и океанах жизнь может самозарождаться без ручного посева.",
			"def": true
		},
		{
			"id": "law_accelerated_evolution",
			"title": "Экстремальный Мутагенез Среды",
			"desc": "Биомы и радиация автоматически наделяют виды новыми генетическими чертами и разумом.",
			"def": true
		},
		{
			"id": "law_autonomous_megastructures",
			"title": "Автономная Космическая Экспансия",
			"desc": "Города Кардашёва I+ сами строят орбитальные лифты и запускают паруса Сферы Дайсона.",
			"def": true
		},
		{
			"id": "law_quantum_anomaly_hazards",
			"title": "Риск Квантовых Аварий при Опытах",
			"desc": "Опасные научные замыслы могут при перегреве порождать на планете аномалии Сингулярности.",
			"def": true
		},
		{
			"id": "law_infinite_combinatorial_science",
			"title": "Бесконечный Синтез Гибридных Теорий",
			"desc": "Цивилизации комбинируют свойства биомов и линз, открывая бесконечные тиры законов физики.",
			"def": true
		},
		{
			"id": "law_stellar_instability",
			"title": "Динамическая Активность Звезды",
			"desc": "Откачка энергии из звезды меняет её температуру и вызывает корональные выбросы.",
			"def": true
		}
	]

	for d in laws:
		var wl := SandboxAssetScript.WorldLawAsset.new()
		wl.id = d["id"]
		wl.title = d["title"]
		wl.description = d["desc"]
		wl.enabled_by_default = d["def"]
		_add_world_law(wl)


# ==============================================================================
# 8. WORLD BEHAVIOUR LIBRARY (Фоновые тики мира)
# ==============================================================================
func _init_world_behaviours() -> void:
	var behaviours := [
		{"id": "wb_thermodynamics_and_lenses", "title": "Термодинамика и Купола Констант", "interval": 0.5},
		{"id": "wb_biome_spread_and_abiogenesis", "title": "Динамика Биомов и Абиогенез", "interval": 1.5},
		{"id": "wb_subspecies_evolution", "title": "Демография и Мутации Видов", "interval": 1.0},
		{"id": "wb_city_build_orders", "title": "Авто-Строительство Городов (BuildOrder)", "interval": 1.2},
		{"id": "wb_plots_and_infinite_science", "title": "Научные Замыслы (Plots) и Открытия", "interval": 0.8},
		{"id": "wb_dyson_swarm_and_star", "title": "Орбитальный Рой и Астрофизика Звезды", "interval": 0.5}
	]

	for d in behaviours:
		var wb := SandboxAssetScript.WorldBehaviourAsset.new()
		wb.id = d["id"]
		wb.title = d["title"]
		wb.interval = d["interval"]
		_add_world_behaviour(wb)


# ==============================================================================
# 9. CULTURAL ETHOS LIBRARY (Социетальные парадигмы и идеологии цивилизаций)
# ==============================================================================
func _init_ethos_traits() -> void:
	var e0 := SandboxAssetScript.CulturalEthosAsset.new()
	e0.id = "ethos_expansionist"
	e0.title = "Экспансионизм Первопроходцев"
	e0.description = "Неудержимое стремление заселять необитаемые острова, развивать колонизацию и раздвигать границы полиса."
	e0.category = "ethos"
	e0.icon_symbol = "E"
	e0.color = Color(0.28, 0.88, 0.42)
	e0.opposite_ethos_id = "ethos_isolationist"
	e0.opinion_same_ethos = 30.0
	e0.opinion_opposite_ethos = -35.0
	e0.expansion_drive = 2.2
	e0.military_aggression = 1.2
	e0.science_focus = 0.9
	e0.trade_affinity = 1.1
	e0.cohesion_stability = 1.0
	e0.preferred_layout = "rings"
	_add_ethos_trait(e0)

	var e1 := SandboxAssetScript.CulturalEthosAsset.new()
	e1.id = "ethos_scientific"
	e1.title = "Технократический Рационализм"
	e1.description = "Приоритет фундаментальных исследований, ускоренного открытия теорий и масштабных мегаструктур."
	e1.category = "ethos"
	e1.icon_symbol = "S"
	e1.color = Color(0.2, 0.85, 1.0)
	e1.opposite_ethos_id = "ethos_traditionalist"
	e1.opinion_same_ethos = 35.0
	e1.opinion_opposite_ethos = -25.0
	e1.expansion_drive = 0.9
	e1.military_aggression = 0.7
	e1.science_focus = 2.2
	e1.trade_affinity = 1.2
	e1.cohesion_stability = 1.2
	e1.preferred_layout = "honeycomb"
	_add_ethos_trait(e1)

	var e2 := SandboxAssetScript.CulturalEthosAsset.new()
	e2.id = "ethos_xenophile"
	e2.title = "Космический Пан-Гуманизм"
	e2.description = "Стремление к мирному сосуществованию, межрасовым альянсам и взаимовыгодной галактической торговле."
	e2.category = "ethos"
	e2.icon_symbol = "X"
	e2.color = Color(0.85, 0.45, 1.0)
	e2.opposite_ethos_id = "ethos_militarist"
	e2.opinion_same_ethos = 45.0
	e2.opinion_opposite_ethos = -45.0
	e2.expansion_drive = 1.1
	e2.military_aggression = 0.5
	e2.science_focus = 1.1
	e2.trade_affinity = 2.5
	e2.cohesion_stability = 1.3
	e2.preferred_layout = "fractal"
	_add_ethos_trait(e2)

	var e3 := SandboxAssetScript.CulturalEthosAsset.new()
	e3.id = "ethos_militarist"
	e3.title = "Гегемония Звёздного Порядка"
	e3.description = "Культ превосходства военной мощи, рейдов на чужие территории и силового принуждения соседей."
	e3.category = "ethos"
	e3.icon_symbol = "M"
	e3.color = Color(1.0, 0.32, 0.32)
	e3.opposite_ethos_id = "ethos_xenophile"
	e3.opinion_same_ethos = 25.0
	e3.opinion_opposite_ethos = -50.0
	e3.expansion_drive = 1.4
	e3.military_aggression = 2.5
	e3.science_focus = 0.8
	e3.trade_affinity = 0.6
	e3.cohesion_stability = 0.85
	e3.preferred_layout = "monolith_mesh"
	_add_ethos_trait(e3)


# ==============================================================================
# 10. DIPLOMACY PLOTS LIBRARY (Замыслы внешней политики)
# ==============================================================================
func _init_diplomacy_plots() -> void:
	var p0 := SandboxAssetScript.PlotAsset.new()
	p0.id = "plot_war_mobilization"
	p0.title = "Военная Мобилизация и Претензия"
	p0.description = "Подготовка полиса к объявлению войны целевому государству и мобилизация воинов."
	p0.category = "diplomacy"
	p0.icon_symbol = "⚔"
	p0.color = Color(1.0, 0.3, 0.3)
	p0.plot_type = "diplomacy_war"
	p0.diplomacy_type = "war"
	p0.progress_needed = 35.0
	p0.energy_cost_per_sec = 1.0
	p0.opinion_threshold = -30.0
	_add_diplomacy_plot(p0)

	var p1 := SandboxAssetScript.PlotAsset.new()
	p1.id = "plot_peace_accord"
	p1.title = "Мирный Договор и Перемирие"
	p1.description = "Дипломатические переговоры о прекращении боевых действий и снятии истощения от войны."
	p1.category = "diplomacy"
	p1.icon_symbol = "🕊"
	p1.color = Color(0.4, 0.9, 0.6)
	p1.plot_type = "diplomacy_peace"
	p1.diplomacy_type = "peace"
	p1.progress_needed = 20.0
	p1.energy_cost_per_sec = 0.5
	p1.opinion_threshold = -10.0
	_add_diplomacy_plot(p1)

	var p2 := SandboxAssetScript.PlotAsset.new()
	p2.id = "plot_alliance_federation"
	p2.title = "Пакт Взаимной Обороны"
	p2.description = "Оформление нерушимого союза с близким по духу полисом."
	p2.category = "diplomacy"
	p2.icon_symbol = "🛡"
	p2.color = Color(0.35, 0.75, 1.0)
	p2.plot_type = "diplomacy_alliance"
	p2.diplomacy_type = "alliance"
	p2.progress_needed = 40.0
	p2.energy_cost_per_sec = 1.5
	p2.opinion_threshold = 55.0
	_add_diplomacy_plot(p2)

	var p3 := SandboxAssetScript.PlotAsset.new()
	p3.id = "plot_trade_route_pact"
	p3.title = "Торговый Пакт Консорциума"
	p3.description = "Учреждение регулярного торгового обмена материей и энергией между двумя полисами."
	p3.category = "diplomacy"
	p3.icon_symbol = "⚖"
	p3.color = Color(1.0, 0.85, 0.25)
	p3.plot_type = "diplomacy_trade"
	p3.diplomacy_type = "trade"
	p3.progress_needed = 25.0
	p3.energy_cost_per_sec = 1.0
	p3.opinion_threshold = 20.0
	_add_diplomacy_plot(p3)


# ==============================================================================
# 11. EXPEDITION BUILD ORDERS LIBRARY (Колониальные верфи и экспедиции)
# ==============================================================================
func _init_expedition_orders() -> void:
	var o0 := SandboxAssetScript.BuildOrderAsset.new()
	o0.id = "order_colony_ship"
	o0.title = "Колониальный Ковчег / Экспедиция"
	o0.description = "Снаряжение исследовательской партии первопроходцев для основания дочернего полиса на дальних берегах."
	o0.category = "expedition"
	o0.icon_symbol = "⛵"
	o0.color = Color(0.4, 0.85, 1.0)
	o0.tier = 2
	o0.required_pop = 35
	o0.required_matter = 45.0
	o0.required_energy = 20.0
	o0.required_science_tier = 1
	o0.max_per_city = 2
	o0.is_orbital = false
	o0.is_megastructure = false
	o0.visual_archetype = "shipyard"
	o0.is_colony_expedition = true
	o0.colony_range_tiles = 18
	_add_expedition_order(o0)


# ==============================================================================
# 12. CATACLYSMS & DESTRUCTIVE POWERS LIBRARY (F5 Божественный Арсенал)
# ==============================================================================
func _init_cataclysm_powers() -> void:
	var p_meteor := SandboxAssetScript.GodPowerAsset.new()
	p_meteor.id = "power_meteor_strike"
	p_meteor.title = "Метеоритный Удар"
	p_meteor.description = "Обрушивает колоссальный болид на планету: формирует ударный кратер, распыляет ударную волну, уничтожает постройки и актеров в эпицентре."
	p_meteor.tab_id = "cosmos"
	p_meteor.power_category = "cataclysm"
	p_meteor.power_type = "cataclysm"
	p_meteor.destructive = true
	p_meteor.building_damage = 150.0
	p_meteor.base_damage = 150.0
	p_meteor.actor_damage = 120.0
	p_meteor.shockwave_radius = 0.35
	p_meteor.shockwave_color = Color(1.0, 0.45, 0.1)
	p_meteor.temp_delta_c = 450.0
	p_meteor.height_delta = -0.28
	p_meteor.radiation_delta = 0.40
	p_meteor.matter_injection = 80.0
	p_meteor.target_biome_id = "biome_actinide_wasteland"
	p_meteor.beam_color = Color(1.0, 0.4, 0.1)
	p_meteor.energy_cost = 45.0
	p_meteor.cooldown = 10.0
	p_meteor.radius_tiles = 3.5
	_add_cataclysm_power(p_meteor)

	var p_lance := SandboxAssetScript.GodPowerAsset.new()
	p_lance.id = "power_antimatter_lance"
	p_lance.title = "Копьё Антиматерии"
	p_lance.description = "Орбитальный пучок античастиц аннигилирует материю в чистую энергию, гарантированно разрушая здания и испаряя биосферу."
	p_lance.tab_id = "cosmos"
	p_lance.power_category = "cataclysm"
	p_lance.power_type = "cataclysm"
	p_lance.destructive = true
	p_lance.building_damage = 999.0
	p_lance.base_damage = 999.0
	p_lance.actor_damage = 500.0
	p_lance.shockwave_radius = 0.20
	p_lance.shockwave_color = Color(0.9, 0.2, 1.0)
	p_lance.height_delta = -0.35
	p_lance.energy_injection = 300.0
	p_lance.target_biome_id = "biome_singularity_swamp"
	p_lance.beam_color = Color(0.9, 0.2, 1.0)
	p_lance.energy_cost = 80.0
	p_lance.cooldown = 20.0
	p_lance.radius_tiles = 2.0
	_add_cataclysm_power(p_lance)

	var p_flare := SandboxAssetScript.GodPowerAsset.new()
	p_flare.id = "power_solar_flare"
	p_flare.title = "Солнечная Вспышка / ЭМИ-Удар"
	p_flare.description = "Корональный выброс массы накрывает планету геомагнитной бурей, перезаряжает энергосеть, временно парализует научные замыслы полисов и повреждает электронику."
	p_flare.tab_id = "cosmos"
	p_flare.power_category = "cataclysm"
	p_flare.power_type = "cataclysm"
	p_flare.destructive = true
	p_flare.building_damage = 30.0
	p_flare.base_damage = 30.0
	p_flare.actor_damage = 15.0
	p_flare.shockwave_radius = 0.80
	p_flare.shockwave_color = Color(1.0, 0.8, 0.25)
	p_flare.energy_injection = 150.0
	p_flare.beam_color = Color(1.0, 0.8, 0.25)
	p_flare.energy_cost = 30.0
	p_flare.cooldown = 15.0
	p_flare.radius_tiles = 8.0
	_add_cataclysm_power(p_flare)

	var p_quake := SandboxAssetScript.GodPowerAsset.new()
	p_quake.id = "power_seismic_quake"
	p_quake.title = "Тектонический Разлом"
	p_quake.description = "Глубинный разлом мантии смещает пласты коры, образуя рифтовые трещины и разрушая городские фундаменты."
	p_quake.tab_id = "alchemy"
	p_quake.power_category = "cataclysm"
	p_quake.power_type = "cataclysm"
	p_quake.destructive = true
	p_quake.building_damage = 45.0
	p_quake.base_damage = 45.0
	p_quake.actor_damage = 25.0
	p_quake.shockwave_radius = 0.40
	p_quake.shockwave_color = Color(0.7, 0.5, 0.3)
	p_quake.height_delta = 0.22
	p_quake.beam_color = Color(0.7, 0.5, 0.3)
	p_quake.energy_cost = 25.0
	p_quake.cooldown = 8.0
	p_quake.radius_tiles = 4.0
	_add_cataclysm_power(p_quake)

	var p_plague := SandboxAssetScript.GodPowerAsset.new()
	p_plague.id = "power_cosmic_plague"
	p_plague.title = "Космическая Чумная Волна"
	p_plague.description = "Внеземной фаговый патоген поражает актеров и сокращает население полисов, стимулируя экстренный отбор адаптивных мутаций."
	p_plague.tab_id = "life"
	p_plague.power_category = "cataclysm"
	p_plague.power_type = "cataclysm"
	p_plague.destructive = true
	p_plague.building_damage = 0.0
	p_plague.base_damage = 60.0
	p_plague.actor_damage = 60.0
	p_plague.shockwave_radius = 0.28
	p_plague.shockwave_color = Color(0.3, 0.9, 0.2)
	p_plague.beam_color = Color(0.3, 0.9, 0.2)
	p_plague.energy_cost = 20.0
	p_plague.cooldown = 12.0
	p_plague.radius_tiles = 3.0
	_add_cataclysm_power(p_plague)

	var p_bloom := SandboxAssetScript.GodPowerAsset.new()
	p_bloom.id = "power_gaia_bloom"
	p_bloom.title = "Дыхание Геи / Биосферный Расцвет"
	p_bloom.description = "Волна биорегенерации очищает радиацию, нормализует климат, залечивает раненых и стимулирует гармонию в полисах."
	p_bloom.tab_id = "life"
	p_bloom.power_category = "cataclysm"
	p_bloom.power_type = "cataclysm"
	p_bloom.destructive = false
	p_bloom.building_damage = 0.0
	p_bloom.base_damage = 0.0
	p_bloom.actor_damage = -100.0
	p_bloom.shockwave_radius = 0.38
	p_bloom.shockwave_color = Color(0.2, 1.0, 0.45)
	p_bloom.radiation_delta = -0.80
	p_bloom.temp_delta_c = 20.0
	p_bloom.target_biome_id = "biome_primordial_ocean"
	p_bloom.beam_color = Color(0.2, 1.0, 0.45)
	p_bloom.energy_cost = 35.0
	p_bloom.cooldown = 10.0
	p_bloom.radius_tiles = 4.0
	_add_cataclysm_power(p_bloom)

	var p_spore := SandboxAssetScript.GodPowerAsset.new()
	p_spore.id = "power_mutagenic_spore"
	p_spore.title = "Мутагенные Споры"
	p_spore.description = "Облако активных спор вызывает каскадную перестройку генома живых актеров и запускает кристаллический мицелий в породе."
	p_spore.tab_id = "life"
	p_spore.power_category = "cataclysm"
	p_spore.power_type = "cataclysm"
	p_spore.destructive = false
	p_spore.building_damage = 0.0
	p_spore.base_damage = 10.0
	p_spore.actor_damage = 10.0
	p_spore.mutation_chance = 0.85
	p_spore.shockwave_radius = 0.25
	p_spore.shockwave_color = Color(0.8, 0.2, 0.9)
	p_spore.beam_color = Color(0.8, 0.2, 0.9)
	p_spore.energy_cost = 25.0
	p_spore.cooldown = 10.0
	p_spore.radius_tiles = 2.5
	_add_cataclysm_power(p_spore)


# ==============================================================================
# 13. TRANSMUTATION POWERS LIBRARY (F5 Космическая Алхимия и Преобразование)
# ==============================================================================
func _init_transmutation_powers() -> void:
	var p_transmuter := SandboxAssetScript.GodPowerAsset.new()
	p_transmuter.id = "power_matter_transmuter"
	p_transmuter.title = "Трансмутатор Материи"
	p_transmuter.description = "Алхимическая матрица конденсирует избыточную энергию в плотную кристаллическую руду и твёрдую материю."
	p_transmuter.tab_id = "alchemy"
	p_transmuter.power_category = "transmutation"
	p_transmuter.power_type = "transmutation"
	p_transmuter.destructive = false
	p_transmuter.shockwave_radius = 0.25
	p_transmuter.shockwave_color = Color(0.1, 0.85, 1.0)
	p_transmuter.matter_injection = 120.0
	p_transmuter.energy_injection = -30.0
	p_transmuter.target_biome_id = "biome_barren_crust"
	p_transmuter.beam_color = Color(0.1, 0.85, 1.0)
	p_transmuter.energy_cost = 50.0
	p_transmuter.cooldown = 12.0
	p_transmuter.radius_tiles = 2.5
	_add_transmutation_power(p_transmuter)

	var p_well := SandboxAssetScript.GodPowerAsset.new()
	p_well.id = "power_zero_point_well"
	p_well.title = "Скважина Нулевой Точки"
	p_well.description = "Квантовый сифон черпает неисчерпаемую энергию вакуума, локально искажая пространственно-временной континуум."
	p_well.tab_id = "cosmos"
	p_well.power_category = "transmutation"
	p_well.power_type = "transmutation"
	p_well.destructive = false
	p_well.shockwave_radius = 0.30
	p_well.shockwave_color = Color(0.4, 0.1, 1.0)
	p_well.energy_injection = 250.0
	p_well.matter_injection = -15.0
	p_well.beam_color = Color(0.4, 0.1, 1.0)
	p_well.energy_cost = 10.0
	p_well.cooldown = 15.0
	p_well.radius_tiles = 3.0
	_add_transmutation_power(p_well)


# ==============================================================================
# 14. PHYSICAL CONSTANTS LIBRARY (F6 Фундаментальные Константы Вселенной)
# ==============================================================================
func _init_physical_constants() -> void:
	var c_g := SandboxAssetScript.PhysicalConstantAsset.new()
	c_g.id = "gravitational_constant"
	c_g.title = "Гравитационная Константа"
	c_g.symbol = "G"
	c_g.min_val = 0.1
	c_g.max_val = 5.0
	c_g.default_val = 1.0
	c_g.current_val = 1.0
	c_g.unit = "G₀"
	c_g.effect_description = "Влияет на устойчивость орбитальных парусов Сферы Дайсона, рельеф коры и разрушительность сейсмических волн."
	_add_physical_constant(c_g)

	var c_c := SandboxAssetScript.PhysicalConstantAsset.new()
	c_c.id = "light_speed"
	c_c.title = "Скорость Света"
	c_c.symbol = "c"
	c_c.min_val = 0.2
	c_c.max_val = 5.0
	c_c.default_val = 1.0
	c_c.current_val = 1.0
	c_c.unit = "c₀"
	c_c.effect_description = "Определяет скорость распространения сигналов, эффективность межполисной торговли и темп космической экспансии."
	_add_physical_constant(c_c)

	var c_entropy := SandboxAssetScript.PhysicalConstantAsset.new()
	c_entropy.id = "cosmic_entropy_rate"
	c_entropy.title = "Космический Темп Энтропии"
	c_entropy.symbol = "σ"
	c_entropy.min_val = 0.0
	c_entropy.max_val = 5.0
	c_entropy.default_val = 1.0
	c_entropy.current_val = 1.0
	c_entropy.unit = "σ₀"
	c_entropy.effect_description = "Управляет естественным износом городских построек, истощением астероидного пояса и рассеиванием энергии."
	_add_physical_constant(c_entropy)

	var c_mut := SandboxAssetScript.PhysicalConstantAsset.new()
	c_mut.id = "mutation_rate_multiplier"
	c_mut.title = "Множитель Темпа Мутаций"
	c_mut.symbol = "μ"
	c_mut.min_val = 0.1
	c_mut.max_val = 10.0
	c_mut.default_val = 1.0
	c_mut.current_val = 1.0
	c_mut.unit = "μ₀"
	c_mut.effect_description = "Определяет вероятность спонтанных генетических скачков, мутаций актеров и возникновения новых ветвей подвидов."
	_add_physical_constant(c_mut)


# ==============================================================================
# 15. ALCHEMICAL REACTION MATRIX (F6 Мульти-Элементная Алхимия)
# ==============================================================================
func _init_alchemical_matrix() -> void:
	# 1. Плазма + Первичный Океан -> Базальтовая Кора + Выделение Материи
	var r1 := SandboxAssetScript.AlchemicalReactionAsset.new()
	r1.id = "reaction_thermal_quench"
	r1.reaction_name = "Термическая Закалка (Плазма + Океан)"
	r1.primary_input = "biome_plasma_inferno"
	r1.secondary_input = "biome_primordial_ocean"
	r1.output_biome_id = "biome_barren_crust"
	r1.temp_result_c = 45.0
	r1.elevation_delta = 0.12
	r1.matter_yield = 40.0
	r1.sfx_id = "sfx_steam_quench"
	_add_alchemical_reaction(r1)

	# 2. Сейсмический Разлом + Базальт -> Магматический Разлом
	var r2 := SandboxAssetScript.AlchemicalReactionAsset.new()
	r2.id = "reaction_magma_fissure"
	r2.reaction_name = "Магматический Разлом (Сейсмика + Базальт)"
	r2.primary_input = "power_seismic_quake"
	r2.secondary_input = "biome_barren_crust"
	r2.output_biome_id = "biome_plasma_inferno"
	r2.temp_result_c = 500.0
	r2.elevation_delta = -0.18
	r2.energy_yield = 60.0
	r2.matter_yield = 25.0
	r2.sfx_id = "sfx_magma_fissure"
	_add_alchemical_reaction(r2)

	# 3. Мутагенная Спора + Кристаллическая Решётка -> Кристаллический Мицелий
	var r3 := SandboxAssetScript.AlchemicalReactionAsset.new()
	r3.id = "reaction_crystalline_mycelium"
	r3.reaction_name = "Кристаллический Мицелий (Споры + Кристаллы)"
	r3.primary_input = "power_mutagenic_spore"
	r3.secondary_input = "biome_crystal_lattice"
	r3.output_biome_id = "biome_crystal_lattice"
	r3.temp_result_c = 22.0
	r3.elevation_delta = 0.02
	r3.energy_yield = 45.0
	r3.matter_yield = 30.0
	r3.sfx_id = "sfx_crystal_resonance"
	_add_alchemical_reaction(r3)

	# 4. Актинидный Могильник + Первичный Океан -> Сингулярное Болото (Радиотроф)
	var r4 := SandboxAssetScript.AlchemicalReactionAsset.new()
	r4.id = "reaction_radiotrophic_bloom"
	r4.reaction_name = "Радиотрофный Био-Синтез (Актиниды + Океан)"
	r4.primary_input = "biome_actinide_wasteland"
	r4.secondary_input = "biome_primordial_ocean"
	r4.output_biome_id = "biome_singularity_swamp"
	r4.temp_result_c = 35.0
	r4.elevation_delta = 0.05
	r4.radiation_delta = -0.25
	r4.matter_yield = 35.0
	r4.sfx_id = "sfx_bio_bloom"
	_add_alchemical_reaction(r4)

	# 5. Крио-Лед + Плазма -> Кристаллический Кварц (ЭМИ Вспышка)
	var r5 := SandboxAssetScript.AlchemicalReactionAsset.new()
	r5.id = "reaction_superconductor_flash"
	r5.reaction_name = "Сверхпроводящая Вспышка (Крио + Плазма)"
	r5.primary_input = "biome_cryo_superconductor"
	r5.secondary_input = "biome_plasma_inferno"
	r5.output_biome_id = "biome_crystal_lattice"
	r5.temp_result_c = 15.0
	r5.elevation_delta = 0.08
	r5.energy_yield = 90.0
	r5.sfx_id = "sfx_plasma_burst"
	_add_alchemical_reaction(r5)

	# 6. Наниты + Базальтовая Кора -> Кибер-Панцирь
	var r6 := SandboxAssetScript.AlchemicalReactionAsset.new()
	r6.id = "reaction_cyber_infusion"
	r6.reaction_name = "Кибернетическая Инфузия (Наниты + Базальт)"
	r6.primary_input = "power_cyber_nanites"
	r6.secondary_input = "biome_barren_crust"
	r6.output_biome_id = "biome_cybercore"
	r6.elevation_delta = 0.06
	r6.matter_yield = 20.0
	r6.energy_yield = 30.0
	r6.sfx_id = "sfx_nanite_swarm"
	_add_alchemical_reaction(r6)

	# 7. Трансмутатор Материи + Плазма -> Актинидный Осадок
	var r7 := SandboxAssetScript.AlchemicalReactionAsset.new()
	r7.id = "reaction_plasma_condensation"
	r7.reaction_name = "Плазменная Конденсация (Трансмутатор + Плазма)"
	r7.primary_input = "power_matter_transmuter"
	r7.secondary_input = "biome_plasma_inferno"
	r7.output_biome_id = "biome_actinide_wasteland"
	r7.temp_result_c = 60.0
	r7.elevation_delta = 0.10
	r7.matter_yield = 85.0
	r7.sfx_id = "sfx_transmutation"
	_add_alchemical_reaction(r7)

