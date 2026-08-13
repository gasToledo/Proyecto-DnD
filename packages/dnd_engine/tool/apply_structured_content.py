"""Aplica equipo inicial y planos desde la revisión estructurada fijada.

Uso:
  python tool/apply_structured_content.py backgrounds.json class-artificer.json
"""

from __future__ import annotations

import json
import re
import sys
import unicodedata
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
ASSETS = ROOT / "packages/dnd_engine/lib/assets/srd_2024"

ITEM_ALIASES = {
    "arrows (20)": "arrows",
    "bolts (20)": "bolts",
    "calligrapher's supplies": "calligraphers-supplies",
    "bullseye lantern": "lantern-bullseye",
    "carpenter's tools": "carpenters-tools",
    "cartographer's tools": "cartographers-tools",
    "fine clothes": "clothes-fine",
    "disguise kit": "disguise-kit",
    "healer's kit": "healers-kit",
    "herbalism kit": "herbalism-kit",
    "holy symbol": None,
    "hooded lantern": "lantern-hooded",
    "ink pen": "ink-pen",
    "iron pot": "pot-iron",
    "map or scroll case": "case-map-or-scroll",
    "light crossbow": "light-crossbow",
    "navigator's tools": "navigators-tools",
    "thieves' tools": "thieves-tools",
    "traveler's clothes": "clothes-travelers",
    "cook's utensils": "cooks-utensils",
    "climber's kit": "climbers-kit",
}

MUSICAL = ["bagpipes", "drum", "dulcimer", "flute", "horn", "lute", "lyre", "pan-flute", "shawm", "viol"]
GAMING = ["dice-set", "dragonchess-set", "playing-card-set", "three-dragon-ante-set"]
ARTISAN = [
    "alchemists-supplies", "brewers-supplies", "calligraphers-supplies",
    "carpenters-tools", "cartographers-tools", "cobblers-tools",
    "cooks-utensils", "glassblowers-tools", "jewelers-tools",
    "leatherworkers-tools", "masons-tools", "painters-supplies",
    "potters-tools", "smiths-tools", "tinkers-tools", "weavers-tools",
    "woodcarvers-tools",
]
HOLY = ["amulet", "emblem", "reliquary"]
ARCANE_FOCUS = ["crystal", "orb", "rod", "staff", "wand"]


def slug(text: str) -> str:
    plain = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]+", "-", plain.lower()).strip("-")


def grant(item=None, quantity=1, coins=None, choose=None):
    value = {}
    if item is not None:
        value["itemId"] = item
    if quantity != 1:
        value["quantity"] = quantity
    if coins:
        value["coins"] = coins
    if choose:
        value["chooseFromItemIds"] = choose
    return value


def option(option_id, grants):
    return {"id": option_id, "label": f"Opción {option_id}", "grants": grants}


def source_item(entry):
    raw = entry["item"].split("|")[0].lower()
    if raw == "holy symbol":
        return grant(choose=HOLY)
    item_id = ITEM_ALIASES.get(raw, slug(raw))
    return grant(item_id, entry.get("quantity", 1))


def background_options(raw):
    out = []
    for equipment in raw.get("startingEquipment", []):
        for option_id, entries in equipment.items():
            grants = []
            for entry in entries:
                if isinstance(entry, str):
                    raw = entry.split("|")[0].lower()
                    if raw == "gaming set":
                        grants.append(grant(choose=GAMING))
                    elif raw == "musical instrument":
                        grants.append(grant(choose=MUSICAL))
                    else:
                        grants.append(source_item({"item": entry}))
                    continue
                if "item" in entry:
                    grants.append(source_item(entry))
                elif "value" in entry:
                    value = entry["value"]
                    assert value % 100 == 0
                    grants.append(grant(coins={"gp": value // 100}))
                elif entry.get("equipmentType") == "instrumentMusical":
                    grants.append(grant(choose=MUSICAL))
                elif entry.get("equipmentType") == "setGaming":
                    grants.append(grant(choose=GAMING))
                elif entry.get("equipmentType") == "toolArtisan":
                    grants.append(grant(choose=ARTISAN))
                else:
                    raise ValueError(f"Equipo no soportado: {entry}")
            out.append(option(option_id.upper(), grants))
    return out


def class_options():
    c = {}
    def a(class_id, package, money, extra=None):
        opts = [option("A", package)]
        if extra:
            opts.append(option("B", extra))
            opts.append(option("C", [grant(coins={"gp": money})]))
        else:
            opts.append(option("B", [grant(coins={"gp": money})]))
        c[class_id] = opts

    a("barbarian", [grant("greataxe"), grant("handaxe", 4), grant("explorers-pack"), grant(coins={"gp": 15})], 75)
    a("bard", [grant("leather"), grant("dagger", 2), grant(choose=MUSICAL), grant("entertainers-pack"), grant(coins={"gp": 19})], 90)
    a("warlock", [grant("leather"), grant("sickle"), grant("dagger", 2), grant("orb"), grant("book"), grant("scholars-pack"), grant(coins={"gp": 15})], 100)
    a("cleric", [grant("chain-shirt"), grant("shield"), grant("mace"), grant("priests-pack"), grant(choose=HOLY), grant(coins={"gp": 7})], 110)
    a("druid", [grant("leather"), grant("shield"), grant("sickle"), grant("wooden-staff"), grant("explorers-pack"), grant("herbalism-kit"), grant(coins={"gp": 9})], 50)
    a("ranger", [grant("studded-leather"), grant("scimitar"), grant("shortsword"), grant("longbow"), grant("arrows"), grant("quiver"), grant("sprig-of-mistletoe"), grant("explorers-pack"), grant(coins={"gp": 7})], 150)
    a("fighter", [grant("chain-mail"), grant("greatsword"), grant("flail"), grant("javelin", 8), grant("dungeoneers-pack"), grant(coins={"gp": 4})], 155,
      [grant("studded-leather"), grant("scimitar"), grant("shortsword"), grant("longbow"), grant("arrows"), grant("quiver"), grant("dungeoneers-pack"), grant(coins={"gp": 11})])
    a("sorcerer", [grant("spear"), grant("dagger", 2), grant("crystal"), grant("dungeoneers-pack"), grant(coins={"gp": 28})], 50)
    a("wizard", [grant("dagger", 2), grant("quarterstaff"), grant("spellbook"), grant("scholars-pack"), grant("robe"), grant(coins={"gp": 5})], 55)
    a("monk", [grant("spear"), grant("dagger", 5), grant(choose=ARTISAN + MUSICAL), grant("explorers-pack"), grant(coins={"gp": 11})], 50)
    a("paladin", [grant("chain-mail"), grant("shield"), grant("longsword"), grant("javelin", 6), grant(choose=HOLY), grant("priests-pack"), grant(coins={"gp": 9})], 150)
    a("rogue", [grant("leather"), grant("dagger", 2), grant("shortsword"), grant("shortbow"), grant("arrows"), grant("quiver"), grant("thieves-tools"), grant("burglars-pack"), grant(coins={"gp": 8})], 100)
    a("artificer", [grant("studded-leather"), grant("dagger"), grant("thieves-tools"), grant("tinkers-tools"), grant("dungeoneers-pack"), grant(coins={"gp": 16})], 150)
    return c


PLAN_OPTIONS = [
    ("bolsa-de-contencion", 2), ("anteojos-de-la-noche", 2),
    ("manifold-tool", 2), ("repeating-shot", 2), ("returning-weapon", 2),
    ("cuerda-de-escalada", 2), ("piedras-mensajeras", 2),
    ("escudo-1", 2), ("varita-del-mago-de-guerra-1", 2), ("arma-1", 2),
    ("botas-elficas", 6), ("boots-of-the-winding-path", 6),
    ("capa-elfica", 6), ("capa-de-la-mantarraya", 6),
    ("dazzling-weapon", 6), ("anteojos-de-encantamiento", 6),
    ("anteojos-de-vision-minuciosa", 6), ("guantes-de-ladron", 6),
    ("helm-of-awareness", 6), ("linterna-de-revelacion", 6),
    ("mind-sharpener", 6), ("collar-de-adaptacion", 6),
    ("flauta-de-la-aparicion", 6), ("repulsion-shield", 6),
    ("anillo-de-natacion", 6), ("anillo-de-caminar-sobre-las-aguas", 6),
    ("escudo-centinela", 6), ("spell-refueling-ring", 6),
    ("varita-de-proyectiles-magicos", 6), ("varita-de-telarana", 6),
    ("arma-de-advertencia", 6), ("armadura-de-resistencia", 10),
    ("daga-de-la-ponzona", 10), ("anillo-de-caida-de-pluma", 10),
    ("anillo-de-salto", 10), ("anillo-de-escudo-mental", 10),
    ("escudo-2", 10), ("varita-del-mago-de-guerra-2", 10),
    ("arma-2", 10), ("armadura-2", 14), ("escudo-atrapaflechas", 14),
    ("lengua-de-fuego", 14), ("anillo-de-libertad-de-accion", 14),
    ("anillo-de-proteccion", 14), ("anillo-del-carnero", 14),
]


def main():
    if len(sys.argv) != 3:
        raise SystemExit("Indicá backgrounds.json y class-artificer.json.")
    structured_backgrounds = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))["background"]
    backgrounds = json.loads((ASSETS / "backgrounds.json").read_text(encoding="utf-8"))
    by_id = {slug(b["name"]): b for b in structured_backgrounds if b.get("source") in {"XPHB", "EFA"}}
    for background in backgrounds:
        source = by_id.get(background["id"])
        if source is None:
            raise ValueError(f"Sin fuente estructurada para {background['id']}")
        background["startingEquipment"] = background_options(source)

    classes = json.loads((ASSETS / "classes.json").read_text(encoding="utf-8"))
    packages = class_options()
    for klass in classes:
        klass["startingEquipment"] = packages[klass["id"]]
        if klass["id"] == "artificer":
            feature = next(f for f in klass["features"] if f["name"] == "Réplica de Objeto Mágico")
            feature["effects"] = [
                *[e for e in feature["effects"] if e.get("type") != "itemChoice"],
                {
                    "type": "itemChoice",
                    "groupId": "artificer-magic-item-plans",
                    "name": "Planos de objeto mágico",
                    "countByLevel": {"2": 4, "6": 5, "10": 6, "14": 7, "18": 8},
                    "replaceable": True,
                    "options": [
                        {"itemId": item_id, "minLevel": level}
                        for item_id, level in PLAN_OPTIONS
                    ],
                },
            ]

    efa_items = json.loads((ASSETS / "efa_magic_items.json").read_text(encoding="utf-8"))
    rarity_values = {
        "common": 10_000,
        "uncommon": 40_000,
        "rare": 400_000,
        "very-rare": 4_000_000,
        "legendary": 20_000_000,
        "artifact": 0,
    }
    for item in efa_items:
        item["costCp"] = rarity_values[item["rarity"]]

    (ASSETS / "backgrounds.json").write_text(json.dumps(backgrounds, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (ASSETS / "classes.json").write_text(json.dumps(classes, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (ASSETS / "efa_magic_items.json").write_text(json.dumps(efa_items, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (ASSETS / "expected_class_ids.json").write_text(json.dumps([c["id"] for c in classes], indent=2) + "\n", encoding="utf-8")
    (ASSETS / "expected_background_ids.json").write_text(json.dumps([b["id"] for b in backgrounds], indent=2) + "\n", encoding="utf-8")
    print(f"{len(classes)} clases y {len(backgrounds)} trasfondos actualizados.")


if __name__ == "__main__":
    main()
