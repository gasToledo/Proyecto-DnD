import 'dart:convert';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Carga el pack de contenido SRD 2024 empaquetado como asset del paquete
/// `dnd_engine`. Reutiliza [ContentRepository.fromJsonPacks], así el motor no
/// depende de Flutter y esta capa solo traduce assets → JSON decodificado.
class AssetContentLoader {
  static const _base = 'packages/dnd_engine/assets/srd_2024';

  static Future<List<Map<String, dynamic>>> _load(String file) async {
    final raw = await rootBundle.loadString('$_base/$file');
    return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  }

  static Future<ContentRepository> loadOfficial() async {
    final manifest = jsonDecode(
      await rootBundle.loadString('$_base/manifest.json'),
    );
    ContentPackManifest.fromJson((manifest as Map).cast<String, dynamic>());
    return ContentRepository.fromJsonPacks(
      races: await _load('races.json'),
      classes: await _load('classes.json'),
      subclasses: await _load('subclasses.json'),
      lineages: await _load('lineages.json'),
      backgrounds: await _load('backgrounds.json'),
      feats: await _load('feats.json'),
      weapons: await _load('weapons.json'),
      armor: await _load('armor.json'),
      spells: await _load('spells.json'),
      creatures: await _load('creatures.json'),
    );
  }
}
