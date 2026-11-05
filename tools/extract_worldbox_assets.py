#!/usr/bin/env python3
"""
Extract authentic WorldBox v0.51.2 sprites, UI frames, nameplates, icons,
and MultiMesh horizontal strip atlases from E:\\Worldbox_v0.51.2\\worldbox_Data
into e:\\Godot_Проекты\\1\\assets\\worldbox\\.
"""

import os
import UnityPy
from PIL import Image

WB_DATA_DIR = r"E:\Worldbox_v0.51.2\worldbox_Data"
OUT_DIR = r"e:\Godot_Проекты\1\assets\worldbox"


def recolor_worldbox_mask(
    img: Image.Image,
    k1_colors=((235, 86, 46), (206, 66, 34), (162, 48, 24), (112, 32, 16)),
    k2_color=(72, 86, 118),
    skin_color=(244, 194, 146),
    hair_color=(96, 58, 34),
    is_unit: bool = False,
) -> Image.Image:
    """Replace WorldBox DynamicSpriteCreator palette-mask pixels with crisp colors."""
    rgba = img.convert("RGBA")
    px = rgba.load()
    w, h = rgba.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            # Pure magenta kingdom roof / tunic mask: r == b and g == 0
            if r == b and g == 0 and r >= 60:
                if r >= 240:
                    c = k1_colors[0]
                elif r >= 190:
                    c = k1_colors[1]
                elif r >= 120:
                    c = k1_colors[2]
                else:
                    c = k1_colors[3]
                px[x, y] = (c[0], c[1], c[2], a)
            # Secondary green mask (0, 255, 0) or (0, 175, 0) -> trousers / secondary trim
            elif r == 0 and g >= 120 and b == 0:
                px[x, y] = (k2_color[0], k2_color[1], k2_color[2], a)
            # Unit skin mask (184, 255, 150) or unit-only green skin shade (74, 131, 31)
            elif (r == 184 and g == 255 and b == 150) or (is_unit and g > r + 45 and g > b + 45):
                px[x, y] = (skin_color[0], skin_color[1], skin_color[2], a)
            # Unit hair mask (227, 228, 43)
            elif r == 227 and g == 228 and b == 43:
                px[x, y] = (hair_color[0], hair_color[1], hair_color[2], a)
    return rgba


def place_bottom_center(cell_w: int, cell_h: int, sprite_img: Image.Image) -> Image.Image:
    """Place sprite_img bottom-centered inside a cell_w x cell_h RGBA canvas (cropping/scaling only if oversized)."""
    canvas = Image.new("RGBA", (cell_w, cell_h), (0, 0, 0, 0))
    # Trim transparent borders first so the sprite sits flush on the ground
    bbox = sprite_img.getbbox()
    if bbox:
        sprite_img = sprite_img.crop(bbox)
    sw, sh = sprite_img.size
    if sw > cell_w or sh > cell_h:
        scale = min(cell_w / max(1, sw), cell_h / max(1, sh))
        nw = max(1, int(round(sw * scale)))
        nh = max(1, int(round(sh * scale)))
        sprite_img = sprite_img.resize((nw, nh), Image.Resampling.NEAREST)
        sw, sh = nw, nh
    ox = (cell_w - sw) // 2
    oy = cell_h - sh
    canvas.alpha_composite(sprite_img, (ox, oy))
    return canvas


def main() -> None:
    os.makedirs(os.path.join(OUT_DIR, "ui"), exist_ok=True)
    os.makedirs(os.path.join(OUT_DIR, "icons"), exist_ok=True)
    os.makedirs(os.path.join(OUT_DIR, "map"), exist_ok=True)

    print("Loading WorldBox v0.51.2 assets...")
    ggm = UnityPy.load(os.path.join(WB_DATA_DIR, "globalgamemanagers"))
    res = UnityPy.load(os.path.join(WB_DATA_DIR, "resources.assets"))

    res_by_id = {obj.path_id: obj for obj in res.objects}
    path_to_sprites = {}
    path_to_tex = {}

    for obj in ggm.objects:
        if obj.type.name == "ResourceManager":
            d = obj.read()
            for path, pptr in d.m_Container:
                ro = res_by_id.get(pptr.path_id)
                if ro is None:
                    continue
                if ro.type.name == "Sprite":
                    path_to_sprites.setdefault(path, []).append(ro.read())
                elif ro.type.name == "Texture2D":
                    path_to_tex.setdefault(path, []).append(ro.read())

    spr_by_name = {}
    tex_by_name = {}
    for obj in res.objects:
        if obj.type.name == "Sprite":
            d = obj.read()
            spr_by_name.setdefault(d.m_Name, []).append(d)
        elif obj.type.name == "Texture2D":
            d = obj.read()
            tex_by_name.setdefault(d.m_Name, []).append(d)

    def get_by_name(name: str) -> Image.Image:
        if name in spr_by_name:
            # Prefer highest resolution if multiple sprites share a name
            best = max(spr_by_name[name], key=lambda s: s.m_Rect.width * s.m_Rect.height)
            return best.image.convert("RGBA")
        if name in tex_by_name:
            best = max(tex_by_name[name], key=lambda t: t.m_Width * t.m_Height)
            return best.image.convert("RGBA")
        raise KeyError(f"Asset '{name}' not found")

    def get_by_path(path: str, sprite_name: str = None) -> Image.Image:
        sps = path_to_sprites.get(path, [])
        if sps:
            if sprite_name:
                for s in sps:
                    if s.m_Name == sprite_name:
                        return s.image.convert("RGBA")
            return sps[0].image.convert("RGBA")
        txs = path_to_tex.get(path, [])
        if txs:
            return txs[0].image.convert("RGBA")
        raise KeyError(f"Path '{path}' (sprite={sprite_name}) not found")

    # 1. Extract UI Frames
    ui_names = [
        "windowBig",
        "windowBigNoTitle",
        "windowInnerSliced",
        "windowInnerSlicedRound",
        "headerBig",
        "bottom_bar",
        "button",
        "button2",
        "buttonSelected",
        "buttonLong",
        "tab_button",
        "tab_button_selected",
        "gene_petri_button",
        "locus_bg_normal",
        "locus_bg_synergy",
        "iconClose",
        "windowNamePlate",
    ]
    for nm in ui_names:
        im = get_by_name(nm)
        im.save(os.path.join(OUT_DIR, "ui", f"{nm}.png"))

    # 2. Extract Icons
    icon_names = [
        # Tabs
        "icon_tab_drawings",
        "icon_tab_creatures",
        "icon_tab_noosphere",
        "icon_tab_nature",
        "icon_tab_bombs",
        "icon_tab_other",
        # Top bar & speeds
        "iconPause",
        "iconClockX1",
        "iconClockX5",
        "iconClockXSonic",
        "iconWorldInfo",
        "iconWorldLaws",
        "iconWorldLog",
        "iconStatistics",
        "iconKnowledge",
        "iconAges",
        "iconSaveLocal",
        "iconBrowse",
        "iconClose",
        # Brushes
        "brush_circ_1",
        "brush_circ_5",
        "brush_circ_15",
        # Ages
        "iconAgeHope",
        "iconAgeSun",
        "iconAgeIce",
        "iconAgeChaos",
        "iconAgeWonders",
        # Powers & World Laws
        "iconTileDeepOcean",
        "iconTileSand",
        "iconTileHills",
        "iconTileShallowWater",
        "iconTileSoil",
        "iconTileMountains",
        "iconShovelPlus",
        "iconShovelMinus",
        "iconRain",
        "iconFire",
        "iconAcid",
        "iconMeteorite",
        "iconLightning",
        "iconTornado",
        "iconEarthquake",
        "iconAtomicBomb",
        "iconAntimatterBomb",
        "iconHeatRay",
        "iconMagnet",
        "iconBlessing",
        "iconInspiration",
        "iconWhisperOfWar",
        "iconCybercore",
        "iconBiomass",
        "iconAlien",
        "iconUfo",
        "iconHumans",
        "iconMonolith",
        "iconCrabzilla",
        "iconSeedGrass",
        "iconSeedSavanna",
        "iconSeedEnchanted",
        "iconSeedCorrupted",
        "iconSeedInfernal",
        "iconSeedCrystal",
        "iconStone",
        "iconGold",
        "iconResGems",
        "iconMythril",
        "iconAdamantine",
        "iconPlague",
        "iconZombie",
        "iconMushSpores",
        "iconTumor",
        "iconSanta",
        "iconDragon",
        "iconCoffee",
        "iconPowerup",
        "iconShield",
    ]
    for nm in icon_names:
        im = get_by_name(nm)
        im.save(os.path.join(OUT_DIR, "icons", f"{nm}.png"))

    # 3. Extract Map Sprites (Nameplates, Bonfires, Boats, Docks)
    nameplate_names = [
        "nameplate_city",
        "nameplate_city_capital",
        "nameplate_kingdom",
        "nameplate_culture",
        "nameplate_religion",
        "nameplate_alliance",
    ]
    for nm in nameplate_names:
        im = get_by_name(nm)
        im.save(os.path.join(OUT_DIR, "map", f"{nm}.png"))

    for i in range(4):
        bf = recolor_worldbox_mask(get_by_name(f"bonfire#0@{i}"))
        bf.save(os.path.join(OUT_DIR, "map", f"bonfire_{i}.png"))

    docks = recolor_worldbox_mask(get_by_name("docks_human#0@0"))
    docks.save(os.path.join(OUT_DIR, "map", "docks_human.png"))

    boat = recolor_worldbox_mask(
        get_by_path("actors/boats/boat_trading_human", "0@0"),
        k1_colors=((245, 238, 220), (225, 214, 192), (195, 182, 158), (156, 142, 118)),
    )
    boat.save(os.path.join(OUT_DIR, "map", "boat_human.png"))

    # 4. Build MultiMesh Atlas 1: Flora & Minerals (10 cols x 24x24 = 240x24)
    # Order matches _flora_type_to_col in cosmic_renderer.gd:
    # 0: bio_tree, 1: savanna_tree, 2: pine_tree, 3: crystal_tree, 4: cyber_node,
    # 5: plasma_vent, 6: palm_tree, 7: stone_ore, 8: gold_ore, 9: crystal_ore
    crystal_trees = path_to_sprites.get("buildings/trees/crystal_tree/main_0", [])
    crystal_tree_img = crystal_trees[0].image.convert("RGBA") if crystal_trees else get_by_path("buildings/trees/celestial_tree/main_0")
    if crystal_tree_img.size[0] <= 12:
        # Scale up 10x10 crystal tree 2x nearest so it matches 20px trees
        crystal_tree_img = crystal_tree_img.resize(
            (crystal_tree_img.size[0] * 2, crystal_tree_img.size[1] * 2),
            Image.Resampling.NEAREST,
        )

    def scale_mineral(im: Image.Image) -> Image.Image:
        # Minerals in WorldBox are ~10x8; scale 1.5x nearest (~15x12) inside 24x24 cell
        return im.resize((int(im.size[0] * 1.5), int(im.size[1] * 1.5)), Image.Resampling.NEAREST)

    flora_cells = [
        get_by_path("buildings/trees/tree_green_1/main_0"),
        get_by_path("buildings/trees/savanna_tree_1/main_0"),
        get_by_path("buildings/trees/pine_tree/main_0"),
        crystal_tree_img,
        get_by_path("buildings/creeps/cybercore/main_0", "main_0_0"),
        get_by_path("buildings/trees/infernal_tree/main_0"),
        get_by_path("buildings/trees/palm_tree/main_0"),
        scale_mineral(get_by_path("buildings/minerals/mineral_stone/main_0")),
        scale_mineral(get_by_path("buildings/minerals/mineral_gold/main_0")),
        scale_mineral(get_by_path("buildings/minerals/mineral_gems/main_0")),
    ]
    atlas_flora = Image.new("RGBA", (24 * 10, 24), (0, 0, 0, 0))
    for idx, cell_src in enumerate(flora_cells):
        cell_im = place_bottom_center(24, 24, cell_src)
        atlas_flora.alpha_composite(cell_im, (idx * 24, 0))
    atlas_flora.save(os.path.join(OUT_DIR, "atlas_flora_wb.png"))

    # 5. Build MultiMesh Atlas 2: Buildings (8 cols x 32x32 = 256x32)
    # Order matches _building_arch_to_col in cosmic_renderer.gd:
    # 0: dome, 1: extractor, 2: reactor, 3: spire, 4: collider, 5: launcher, 6: elevator, 7: anchor
    building_cells = [
        recolor_worldbox_mask(get_by_name("2house_human#0")),
        recolor_worldbox_mask(get_by_name("mine#0")),
        recolor_worldbox_mask(get_by_name("1hall_human#0")),
        recolor_worldbox_mask(get_by_name("temple_human#0")),
        recolor_worldbox_mask(get_by_name("barracks_human#0")),
        recolor_worldbox_mask(get_by_path("buildings/nature/monolith/main_0", "main_0_0")),
        recolor_worldbox_mask(get_by_name("statue#0")),
        recolor_worldbox_mask(get_by_name("2hall_human#0")),
    ]
    atlas_buildings = Image.new("RGBA", (32 * 8, 32), (0, 0, 0, 0))
    for idx, cell_src in enumerate(building_cells):
        cell_im = place_bottom_center(32, 32, cell_src)
        atlas_buildings.alpha_composite(cell_im, (idx * 32, 0))
    atlas_buildings.save(os.path.join(OUT_DIR, "atlas_buildings_wb.png"))

    # 6. Build MultiMesh Atlas 3: Actors (10 cols x 12x12 = 120x12)
    # Order matches _actor_key_to_col in cosmic_renderer.gd:
    # carbon_0, carbon_1, silicon_0, silicon_1, plasma_0, plasma_1, cyber_0, cyber_1, quantum_0, quantum_1
    def build_humanoid_frame(
        body_path: str,
        walk_name: str,
        head_path: str,
        head_name: str,
        k1_colors,
        k2_color,
        skin_color,
        hair_color,
    ) -> Image.Image:
        body_raw = get_by_path(body_path, walk_name)
        body = recolor_worldbox_mask(body_raw, k1_colors, k2_color, skin_color, hair_color, is_unit=True)
        b_bbox = body.getbbox()
        if b_bbox:
            body = body.crop(b_bbox)
        canvas = Image.new("RGBA", (12, 12), (0, 0, 0, 0))
        bw, bh = body.size
        bx = (12 - bw) // 2
        by = 12 - bh
        canvas.alpha_composite(body, (bx, by))
        if head_path:
            try:
                head_raw = get_by_path(head_path, head_name)
                head = recolor_worldbox_mask(head_raw, k1_colors, k2_color, skin_color, hair_color, is_unit=True)
                h_bbox = head.getbbox()
                if h_bbox:
                    head = head.crop(h_bbox)
                hx = (12 - head.size[0]) // 2
                # Seat the head directly on top of the cropped torso (1px overlap on neck)
                hy = max(0, by - head.size[1] + 1)
                canvas.alpha_composite(head, (hx, hy))
            except Exception:
                pass
        return canvas

    actor_cells = [
        # Carbon (Human citizen walk 0 & 1)
        build_humanoid_frame(
            "actors/species/civs/human/male_1",
            "walk_0",
            "actors/species/civs/human/heads_male",
            "head_1",
            ((228, 72, 52), (196, 52, 38), (156, 38, 28), (112, 24, 18)),
            (64, 78, 112),
            (244, 194, 146),
            (96, 58, 34),
        ),
        build_humanoid_frame(
            "actors/species/civs/human/male_1",
            "walk_1",
            "actors/species/civs/human/heads_male",
            "head_1",
            ((228, 72, 52), (196, 52, 38), (156, 38, 28), (112, 24, 18)),
            (64, 78, 112),
            (244, 194, 146),
            (96, 58, 34),
        ),
        # Silicon (Crystal Golem walk 0 & 1)
        build_humanoid_frame(
            "actors/species/civs/civ_crystal_golem/male_1",
            "walk_0",
            "actors/species/civs/civ_crystal_golem/heads_male",
            "head_0",
            ((90, 230, 250), (62, 190, 224), (42, 145, 185), (28, 98, 136)),
            (48, 125, 165),
            (130, 242, 255),
            (190, 252, 255),
        ),
        build_humanoid_frame(
            "actors/species/civs/civ_crystal_golem/male_1",
            "walk_1",
            "actors/species/civs/civ_crystal_golem/heads_male",
            "head_0",
            ((90, 230, 250), (62, 190, 224), (42, 145, 185), (28, 98, 136)),
            (48, 125, 165),
            (130, 242, 255),
            (190, 252, 255),
        ),
        # Plasma (Fire Elemental idle 0 & 1)
        place_bottom_center(12, 12, recolor_worldbox_mask(get_by_path("actors/species/other/fire_elemental_blob/main", "idle_0"))),
        place_bottom_center(12, 12, recolor_worldbox_mask(get_by_path("actors/species/other/fire_elemental_blob/main", "idle_1"))),
        # Cyber (Assimilator walk 0 & 1)
        place_bottom_center(12, 12, recolor_worldbox_mask(get_by_path("actors/species/other/assimilator/main", "walk_0"))),
        place_bottom_center(12, 12, recolor_worldbox_mask(get_by_path("actors/species/other/assimilator/main", "walk_1"))),
        # Quantum (Alien walk 0 & 1)
        build_humanoid_frame(
            "actors/species/other/alien/male_1",
            "walk_0",
            "actors/species/other/alien/heads_male",
            "head_0",
            ((186, 110, 255), (148, 78, 225), (112, 52, 185), (78, 32, 138)),
            (72, 212, 232),
            (162, 245, 198),
            (120, 220, 255),
        ),
        build_humanoid_frame(
            "actors/species/other/alien/male_1",
            "walk_1",
            "actors/species/other/alien/heads_male",
            "head_0",
            ((186, 110, 255), (148, 78, 225), (112, 52, 185), (78, 32, 138)),
            (72, 212, 232),
            (162, 245, 198),
            (120, 220, 255),
        ),
    ]
    atlas_actors = Image.new("RGBA", (12 * 10, 12), (0, 0, 0, 0))
    for idx, cell_im in enumerate(actor_cells):
        atlas_actors.alpha_composite(cell_im, (idx * 12, 0))
    atlas_actors.save(os.path.join(OUT_DIR, "atlas_actors_wb.png"))

    print("Extraction complete!")
    print("  UI textures:", len(os.listdir(os.path.join(OUT_DIR, "ui"))))
    print("  Icons:", len(os.listdir(os.path.join(OUT_DIR, "icons"))))
    print("  Map sprites:", len(os.listdir(os.path.join(OUT_DIR, "map"))))
    print("  Atlases: atlas_flora_wb.png, atlas_buildings_wb.png, atlas_actors_wb.png")


if __name__ == "__main__":
    main()
