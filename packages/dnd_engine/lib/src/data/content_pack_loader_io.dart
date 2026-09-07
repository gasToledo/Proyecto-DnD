import 'dart:convert';
import 'dart:io';

import 'content_repository.dart';

/// Carga un pack desde un directorio: exige un manifiesto válido y lee los
/// catálogos JSON. Los catálogos faltantes se tratan como listas vacías.
///
/// Vive en un archivo aparte de `content_repository.dart` porque es el único
/// punto del motor que usa `dart:io`; `content_repository.dart` lo alcanza
/// mediante una importación condicional para que un build web nunca lo
/// resuelva (ver `content_pack_loader_stub.dart`).
Future<ContentRepository> loadContentRepositoryFromDirectory(
  String dirPath,
) async {
  Future<List<Map<String, dynamic>>> read(String file) async {
    final f = File('$dirPath/$file');
    if (!await f.exists()) return const [];
    return (jsonDecode(await f.readAsString()) as List)
        .cast<Map<String, dynamic>>();
  }

  final manifestFile = File('$dirPath/manifest.json');
  if (!await manifestFile.exists()) {
    throw const FormatException(
      'El paquete de contenido no contiene manifest.json.',
    );
  }
  ContentPackManifest.fromJson(
    (jsonDecode(await manifestFile.readAsString()) as Map)
        .cast<String, dynamic>(),
  );

  final items = [
    ...await read('items.json'),
    ...await read('magic_items.json'),
    ...await read('efa_magic_items.json'),
  ];
  return ContentRepository.fromJsonPacks(
    races: await read('races.json'),
    classes: await read('classes.json'),
    subclasses: await read('subclasses.json'),
    lineages: await read('lineages.json'),
    backgrounds: await read('backgrounds.json'),
    feats: await read('feats.json'),
    weapons: await read('weapons.json'),
    armor: await read('armor.json'),
    items: items,
    spells: await read('spells.json'),
    creatures: await read('creatures.json'),
  );
}
