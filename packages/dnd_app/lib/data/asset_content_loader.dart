import 'dart:convert';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:flutter/services.dart' show rootBundle;

const _base = 'packages/dnd_engine/assets/srd_2024';

const _packs = [
  'races',
  'classes',
  'subclasses',
  'lineages',
  'backgrounds',
  'feats',
  'weapons',
  'armor',
  'items',
  'magic_items',
  'efa_magic_items',
  'spells',
  'creatures',
];

/// Carga el pack SRD 2024 empaquetado como asset.
///
/// Los archivos se piden todos juntos y no de a uno: en producción cada
/// pedido cruza Cloudflare y el túnel hasta el servidor, y en serie eran
/// catorce viajes de ida y vuelta sumados antes de ver la biblioteca.
/// `Future.wait` y no un `await` suelto por archivo: si uno falla mientras se
/// espera a otro, su error quedaría sin nadie que lo atienda.
Future<ContentRepository> loadOfficialContent() async {
  final raw = await Future.wait([
    for (final name in ['manifest', ..._packs])
      rootBundle.loadString('$_base/$name.json'),
  ]);
  ContentPackManifest.fromJson(
    (jsonDecode(raw.first) as Map).cast<String, dynamic>(),
  );
  final pack = {
    for (final (i, name) in _packs.indexed)
      name: (jsonDecode(raw[i + 1]) as List).cast<Map<String, dynamic>>(),
  };
  return ContentRepository.fromJsonPacks(
    races: pack['races']!,
    classes: pack['classes']!,
    subclasses: pack['subclasses']!,
    lineages: pack['lineages']!,
    backgrounds: pack['backgrounds']!,
    feats: pack['feats']!,
    weapons: pack['weapons']!,
    armor: pack['armor']!,
    items: [
      ...pack['items']!,
      ...pack['magic_items']!,
      ...pack['efa_magic_items']!,
    ],
    spells: pack['spells']!,
    creatures: pack['creatures']!,
  );
}
