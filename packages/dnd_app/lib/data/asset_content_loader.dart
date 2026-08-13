import 'dart:convert';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/services.dart' show rootBundle;

const _base = 'packages/dnd_engine/assets/srd_2024';

Future<List<Map<String, dynamic>>> _load(String file) async {
  final raw = await rootBundle.loadString('$_base/$file');
  return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
}

/// Carga el pack SRD 2024 empaquetado como asset.
Future<ContentRepository> loadOfficialContent() async {
  final manifest = jsonDecode(
    await rootBundle.loadString('$_base/manifest.json'),
  );
  ContentPackManifest.fromJson((manifest as Map).cast<String, dynamic>());
  final items = [
    ...await _load('items.json'),
    ...await _load('magic_items.json'),
    ...await _load('efa_magic_items.json'),
  ];
  return ContentRepository.fromJsonPacks(
    races: await _load('races.json'),
    classes: await _load('classes.json'),
    subclasses: await _load('subclasses.json'),
    lineages: await _load('lineages.json'),
    backgrounds: await _load('backgrounds.json'),
    feats: await _load('feats.json'),
    weapons: await _load('weapons.json'),
    armor: await _load('armor.json'),
    items: items,
    spells: await _load('spells.json'),
    creatures: await _load('creatures.json'),
  );
}
