"""Genera el catálogo mágico español desde el SRD 5.2.1 local.

Uso:
  python tool/generate_magic_items.py <SP_SRD_CC_v5.2.1.pdf>

La revisión de la fuente estructurada complementaria queda documentada en la
auditoría. Este generador usa el PDF normativo para nombres y texto españoles;
no necesita red y escribe solo activos derivados versionables.
"""

from __future__ import annotations

import json
import re
import sys
import unicodedata
from pathlib import Path

import pdfplumber


ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "packages/dnd_engine/lib/assets/srd_2024"
FIRST_PAGE = 228
LAST_PAGE = 277


def slug(text: str) -> str:
    plain = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]+", "-", plain.lower()).strip("-")


def lines_in_reading_order(pdf):
    for page_number in range(FIRST_PAGE, LAST_PAGE + 1):
        page = pdf.pages[page_number - 1]
        words = page.extract_words(extra_attrs=["size", "fontname"])
        for column, (left, right) in enumerate(((54, 300), (305, 548))):
            selected = [
                word
                for word in words
                if left <= word["x0"] < right and 30 <= word["top"] < 725
            ]
            groups: list[list[dict]] = []
            for word in sorted(selected, key=lambda w: (w["top"], w["x0"])):
                if not groups or abs(groups[-1][0]["top"] - word["top"]) > 1.2:
                    groups.append([word])
                else:
                    groups[-1].append(word)
            for group in groups:
                group.sort(key=lambda w: w["x0"])
                yield {
                    "page": page_number,
                    "column": column,
                    "top": group[0]["top"],
                    "text": " ".join(w["text"] for w in group),
                    "heading": all(round(w["size"], 1) == 12.0 for w in group),
                }


def extract_blocks(pdf):
    raw = list(lines_in_reading_order(pdf))
    candidates = []
    current = None
    for line in raw:
        if line["heading"]:
            if current is not None:
                candidates.append(current)
            current = {
                "name": line["text"],
                "lines": [],
                "page": line["page"],
                "column": line["column"],
                "top": line["top"],
            }
        elif current is not None:
            current["lines"].append(line["text"])
    if current is not None:
        candidates.append(current)

    # Los títulos largos pueden ocupar dos líneas consecutivas a 12 pt.
    merged = []
    for candidate in candidates:
        continuation = candidate["name"][:1].islower()
        if (
            merged
            and merged[-1]["page"] == candidate["page"]
            and merged[-1]["column"] == candidate["column"]
            and (not merged[-1]["lines"] or continuation)
        ):
            merged[-1]["name"] += " " + candidate["name"]
            merged[-1]["lines"] = candidate["lines"]
        else:
            merged.append(candidate)

    category = re.compile(
        r"^(Objeto maravilloso|Anillo|Arma|Armadura|Bastón|Cetro|Munición|"
        r"Pergamino|Poción|Varita)",
        re.IGNORECASE,
    )
    blocks = []
    for block in merged:
        if not block["lines"]:
            continue
        metadata_index = next(
            (
                index
                for index, line in enumerate(block["lines"][:8])
                if category.search(line)
            ),
            None,
        )
        if metadata_index is None:
            continue
        # La clasificación puede partirse en dos líneas.
        metadata = " ".join(block["lines"][metadata_index : metadata_index + 2])
        block["metadata"] = metadata
        block["description"] = "\n".join(block["lines"][metadata_index:])
        blocks.append(block)
    return blocks


def rarity(metadata: str) -> str:
    value = metadata.lower()
    if "artefacto" in value:
        return "artifact"
    if "legendari" in value:
        return "legendary"
    if "muy rar" in value:
        return "very-rare"
    if "infrecuente" in value:
        return "uncommon"
    if re.search(r"\brar[oa]\b", value):
        return "rare"
    return "common"


def base_kind(metadata: str) -> str | None:
    value = metadata.lower()
    if value.startswith("arma ") or value.startswith("arma("):
        return "weapon"
    if value.startswith("armadura"):
        return "shield" if "escudo" in value else "armor"
    return None


def cost_cp(item_rarity: str, metadata: str) -> int:
    values = {
        "common": 10_000,
        "uncommon": 40_000,
        "rare": 400_000,
        "very-rare": 4_000_000,
        "legendary": 20_000_000,
        "artifact": 0,
    }
    value = values[item_rarity]
    return value // 2 if metadata.lower().startswith("poción") else value


def passive_effects(name: str, metadata: str):
    lower = name.lower()
    effects = []
    if lower in {"anillo de protección", "capa de protección"}:
        effects.append({"type": "armorClassBonus", "amount": 1})
        effects.append({"type": "savingThrowBonus", "amount": 1})
    if "visión en la oscuridad" in metadata.lower() or lower == "anteojos de la noche":
        effects.append({"type": "darkvision", "range": 18})
    fixed_scores = {
        "amuleto de salud": ("constitution", 19),
        "diadema de intelecto": ("intelligence", 19),
        "guanteletes de fuerza de ogro": ("strength", 19),
    }
    if lower in fixed_scores:
        ability, score = fixed_scores[lower]
        effects.append({"type": "setAbilityScore", "ability": ability, "score": score})
    resistance = {
        "anillo de calidez": "cold",
        "botas de las tierras invernales": "cold",
        "broche escudo": "force",
    }.get(lower)
    if resistance:
        effects.append({"type": "resistance", "damageType": resistance})
    if lower == "colgante de inmunidad al veneno":
        effects.append({"type": "immunity", "damageType": "poison"})
    return effects


def expand(block):
    names = [block["name"]]
    if "+1, +2 o +3" in block["name"]:
        names = [block["name"].replace("+1, +2 o +3", f"+{bonus}") for bonus in (1, 2, 3)]
    result = []
    for name in names:
        match = re.search(r"\+([123])\b", name)
        item_rarity = rarity(block["metadata"])
        result.append(
            {
                "id": slug(name),
                "name": name,
                "source": "srd_2024",
                "category": "magic",
                "weight": 0,
                "costCp": cost_cp(item_rarity, block["metadata"]),
                "description": block["description"],
                "rarity": item_rarity,
                "requiresAttunement": "requiere sintonización" in block["metadata"].lower(),
                **({"magicBonus": int(match.group(1))} if match else {}),
                **({"baseItemKind": base_kind(block["metadata"])} if base_kind(block["metadata"]) else {}),
                **({"effects": passive_effects(name, block["metadata"])} if passive_effects(name, block["metadata"]) else {}),
                "sourcePage": block["page"],
            }
        )
    return result


def main():
    if len(sys.argv) != 2:
        raise SystemExit("Indicá la ruta al PDF del SRD 5.2.1.")
    with pdfplumber.open(Path(sys.argv[1])) as pdf:
        blocks = extract_blocks(pdf)
    items = [item for block in blocks for item in expand(block)]
    ids = [item["id"] for item in items]
    if len(ids) != len(set(ids)):
        duplicates = sorted({item for item in ids if ids.count(item) > 1})
        raise SystemExit(f"IDs duplicados: {duplicates}")
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "magic_items.json").write_text(
        json.dumps(items, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    (OUT / "expected_magic_item_ids.json").write_text(
        json.dumps(ids, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(f"{len(blocks)} bloques; {len(items)} entradas mágicas.")


if __name__ == "__main__":
    main()
