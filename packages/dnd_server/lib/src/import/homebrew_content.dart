import 'package:dnd_engine/dnd_engine.dart';

import '../util/safe_path.dart';

const homebrewCategories = [
  'weapons',
  'armor',
  'items',
  'feats',
  'races',
  'backgrounds',
  'spells',
  'creatures',
];

/// Valida y normaliza el mapa de categorías antes de escribir una sola fila.
Map<String, List<Map<String, dynamic>>> parseHomebrewContent(
  Map<String, dynamic> content,
) {
  final unknown = content.keys.where(
    (key) => !homebrewCategories.contains(key),
  );
  if (unknown.isNotEmpty) {
    throw FormatException(
      'Categoría de homebrew no reconocida: ${unknown.first}.',
    );
  }

  return {
    for (final category in homebrewCategories)
      category: _documentsOf(content[category], category),
  };
}

List<Map<String, dynamic>> _documentsOf(Object? raw, String category) {
  if (raw == null) return [];
  if (raw is! List) {
    throw FormatException('La categoría $category debe ser una lista.');
  }
  return [
    for (final value in raw)
      validateHomebrewDocument(category, _jsonMap(value, category)),
  ];
}

Map<String, dynamic> _jsonMap(Object? value, String category) {
  if (value is! Map) {
    throw FormatException(
      'La categoría $category contiene una entrada inválida.',
    );
  }
  return value.cast<String, dynamic>();
}

Map<String, dynamic> validateHomebrewDocument(
  String category,
  Map<String, dynamic> document,
) {
  if (!homebrewCategories.contains(category)) {
    throw const FormatException('Categoría de homebrew no reconocida.');
  }
  final id = document['id'];
  if (id is! String) {
    throw FormatException('Una entrada de $category no tiene un id válido.');
  }
  requireSafePathSegment(id, label: 'id de homebrew');
  if (document['source'] != 'homebrew') {
    throw FormatException('La entrada "$id" debe tener origen homebrew.');
  }

  try {
    switch (category) {
      case 'weapons':
        Weapon.fromJson(document);
      case 'armor':
        Armor.fromJson(document);
      case 'items':
        Item.fromJson(document);
      case 'feats':
        Feat.fromJson(document);
      case 'races':
        Race.fromJson(document);
      case 'backgrounds':
        Background.fromJson(document);
      case 'spells':
        Spell.fromJson(document);
      case 'creatures':
        Creature.fromJson(document);
    }
  } catch (error) {
    throw FormatException('Entrada homebrew "$id" inválida: $error');
  }
  return document;
}
