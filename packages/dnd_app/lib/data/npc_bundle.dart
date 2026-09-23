import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dnd_engine/dnd_engine.dart';

/// Un retrato que viaja en el archivo: de quién es (`npc` o `character`), la
/// clave que tiene en esta cuenta y sus bytes.
typedef NpcBundlePortrait = ({String owner, String key, Uint8List bytes});

/// Lo que se ve de un archivo de PNJ antes de importarlo.
class NpcBundlePreview {
  final Npc npc;
  final Character? sheet;
  final Map<String, List<Map<String, dynamic>>> homebrew;
  final int portraitCount;

  const NpcBundlePreview({
    required this.npc,
    this.sheet,
    this.homebrew = const {},
    this.portraitCount = 0,
  });

  /// Los nombres del homebrew que trae, para la vista previa.
  List<String> get homebrewNames => [
    for (final docs in homebrew.values)
      for (final doc in docs) '${doc['name'] ?? doc['id']}',
  ];
}

/// El archivo con que un DM le pasa un PNJ a otro (tipo `dnd_npc`).
///
/// El servidor tiene su propio lector (`NpcBundleCodec` en `dnd_server`) y es
/// quien decide si el archivo vale: este lado solo lo arma, y lo lee para la
/// vista previa. Es un formato aparte del respaldo a propósito: el respaldo es
/// de personajes jugadores, y un PNJ que entrara por ahí terminaría en «Mis
/// personajes».
class NpcBundleCodec {
  static const type = 'dnd_npc';
  static const formatVersion = 1;
  static const manifestName = 'npc-bundle.json';

  static Uint8List encode({
    required Npc npc,
    Character? sheet,
    Map<String, List<Map<String, dynamic>>> homebrew = const {},
    List<NpcBundlePortrait> portraits = const [],
  }) {
    final archive = Archive();
    final entries = <Map<String, dynamic>>[];
    for (final (i, portrait) in portraits.indexed) {
      final file = 'portraits/$i.${_extensionOf(portrait.bytes)}';
      archive.addFile(ArchiveFile.bytes(file, portrait.bytes));
      entries.add({'file': file, 'owner': portrait.owner, 'key': portrait.key});
    }
    final manifest = {
      'type': type,
      'formatVersion': formatVersion,
      'npc': npc.toJson(),
      if (sheet != null) 'character': sheet.toJson(),
      if (homebrew.values.any((docs) => docs.isNotEmpty)) 'homebrew': homebrew,
      'portraits': entries,
    };
    archive.addFile(
      ArchiveFile.bytes(manifestName, utf8.encode(jsonEncode(manifest))),
    );
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  /// Lee lo necesario para mostrar qué trae el archivo. Lanza
  /// [FormatException] si no es un PNJ exportado y
  /// [UnsupportedDataVersionException] si viene de una versión futura.
  static NpcBundlePreview preview(List<int> bytes) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const FormatException('El archivo no es un ZIP válido.');
    }
    final manifestFile = archive.findFile(manifestName);
    final content = manifestFile?.readBytes();
    if (content == null) {
      throw const FormatException('El archivo no es un PNJ exportado.');
    }
    final manifest = jsonDecode(utf8.decode(content));
    if (manifest is! Map || manifest['type'] != type) {
      throw const FormatException('El archivo no es un PNJ exportado.');
    }
    final version = manifest['formatVersion'];
    if (version is int && version > formatVersion) {
      throw UnsupportedDataVersionException(
        dataType: 'archivo de PNJ',
        found: version,
        supported: formatVersion,
      );
    }
    final rawSheet = manifest['character'];
    final rawHomebrew = manifest['homebrew'];
    return NpcBundlePreview(
      npc: Npc.fromJson((manifest['npc'] as Map).cast<String, dynamic>()),
      sheet: rawSheet is Map
          ? Character.fromJson(rawSheet.cast<String, dynamic>())
          : null,
      homebrew: rawHomebrew is Map
          ? {
              for (final e in rawHomebrew.entries)
                '${e.key}': [
                  for (final doc in (e.value as List? ?? const []))
                    if (doc is Map) doc.cast<String, dynamic>(),
                ],
            }
          : const {},
      portraitCount: (manifest['portraits'] as List? ?? const []).length,
    );
  }

  static String _extensionOf(Uint8List bytes) {
    if (bytes.length > 3 && bytes[0] == 0xFF && bytes[1] == 0xD8) return 'jpg';
    if (bytes.length > 11 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'webp';
    }
    return 'png';
  }
}

/// El contenido oficial que la ficha de [preview] usa y este catálogo no tiene.
///
/// Lo mira el cliente porque el servidor no carga el catálogo. Un PNJ que
/// venga de una instalación con más libros cargados (PHB, Forge of the
/// Artificer) no se importa a medias: se avisa qué falta y no se escribe nada.
/// El homebrew que viaja en el archivo cuenta como disponible.
List<String> missingOfficialContent(
  NpcBundlePreview preview,
  ContentRepository repo,
) {
  final sheet = preview.sheet;
  if (sheet == null) return const [];
  final bundled = {
    for (final docs in preview.homebrew.values)
      for (final doc in docs) doc['id'],
  };
  bool known(String id, bool Function(String) inRepo) =>
      inRepo(id) || bundled.contains(id);
  return [
    if (!known(sheet.raceId, (id) => repo.race(id) != null))
      'especie «${sheet.raceId}»',
    for (final id in sheet.classHistory.toSet())
      if (!known(id, (id) => repo.characterClass(id) != null)) 'clase «$id»',
    for (final id in sheet.subclassIds.values)
      if (!known(id, (id) => repo.subclass(id) != null)) 'subclase «$id»',
    if (!known(sheet.backgroundId, (id) => repo.background(id) != null))
      'trasfondo «${sheet.backgroundId}»',
  ];
}
