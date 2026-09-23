import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dnd_engine/dnd_engine.dart';

import 'backup_bundle.dart';
import 'homebrew_store.dart';

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

  /// Rearma el archivo de un personaje exportado desde «Mis personajes»
  /// (`dnd_bundle`) como el de un PNJ con ficha: el personaje retirado de un
  /// jugador vuelve a la mesa en manos del DM. Cualquier otro archivo vuelve
  /// tal cual, y [preview] decide si es un PNJ.
  ///
  /// Se convierte acá y no en el servidor porque el servidor ya sabe importar
  /// un PNJ con ficha, retratos y homebrew: una segunda ruta de importación
  /// sería una segunda puerta que validar. Al revés no hay camino: un PNJ
  /// nunca se traspasa a un jugador.
  ///
  /// El trasfondo y las entradas del Diario pasan al PNJ, porque la ficha de
  /// un PNJ no muestra el Diario. Las imágenes del Diario no viajan: una nota
  /// de PNJ es solo texto.
  static Uint8List adoptCharacterExport(Uint8List bytes) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      return bytes;
    }
    Object? json(String name) {
      final content = archive.findFile(name)?.readBytes();
      return content == null ? null : jsonDecode(utf8.decode(content));
    }

    final manifest = json('manifest.json');
    if (manifest is! Map || manifest['type'] != BackupBundleCodec.type) {
      return bytes;
    }
    final version = manifest['formatVersion'];
    if (version is int && version > BackupBundleCodec.formatVersion) {
      throw UnsupportedDataVersionException(
        dataType: 'respaldo',
        found: version,
        supported: BackupBundleCodec.formatVersion,
      );
    }
    final entries = manifest['characters'] as List? ?? const [];
    if (entries.length != 1) {
      throw FormatException(
        entries.isEmpty
            ? 'El archivo no trae ningún personaje.'
            : 'El respaldo trae ${entries.length} personajes: exportá desde '
                  '«Mis personajes» solo el que quieras sumar como PNJ.',
      );
    }
    final entry = entries.single as Map;
    final original = Character.fromJson(
      (json(entry['file'] as String) as Map).cast<String, dynamic>(),
    );

    // El respaldo nombra cada retrato por su posición en `portraitPaths`
    // (`portraits/<id>/<i>.png`); uno que no se pudo leer al exportar falta,
    // y por eso se busca por número y no por orden.
    final portraits = <NpcBundlePortrait>[];
    for (final file in (entry['portraits'] as List? ?? const [])) {
      final index = RegExp(r'/(\d+)\.png$').firstMatch('$file')?.group(1);
      final content = archive.findFile('$file')?.readBytes();
      final i = index == null ? null : int.parse(index);
      if (content == null || i == null || i >= original.portraitPaths.length) {
        continue;
      }
      portraits.add((
        owner: 'character',
        key: original.portraitPaths[i],
        bytes: content,
      ));
    }

    final homebrewFile = manifest['homebrewFile'];
    final allHomebrew = homebrewFile is String ? json(homebrewFile) : null;
    final homebrew = allHomebrew is Map
        ? homebrewUsedBy(original, {
            for (final e in allHomebrew.entries)
              '${e.key}': [
                for (final doc in (e.value as List? ?? const []))
                  if (doc is Map) doc.cast<String, dynamic>(),
              ],
          })
        : const <String, List<Map<String, dynamic>>>{};

    final npc = Npc(
      id: 'importado',
      name: original.name,
      sheetKind: NpcSheetKind.character,
      background: original.background,
      notes: [
        for (final e in original.diary)
          if (e.kind != DiaryEntryKind.image &&
              [e.title, e.body].any((t) => t.trim().isNotEmpty))
            NpcNote(
              id: 'nota-${e.entryId}',
              date: e.createdAt ?? DateTime.now(),
              text: [
                e.title,
                e.body,
              ].where((t) => t.trim().isNotEmpty).join('\n'),
            ),
      ],
    );
    // Vaciados en la ficha para que no quede una copia que nadie ve.
    final sheet = Character.fromJson(
      original.toJson()
        ..['background'] = ''
        ..['diary'] = const [],
    );
    return encode(
      npc: npc,
      sheet: sheet,
      homebrew: homebrew,
      portraits: portraits,
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

/// El homebrew que usa la ficha: sin él, del otro lado no abriría.
Map<String, List<Map<String, dynamic>>> homebrewUsedBy(
  Character sheet,
  Map<String, List<Map<String, dynamic>>> all,
) => {
  for (final entry in all.entries)
    if ([
          for (final doc in entry.value)
            if (charactersUsing('${doc['id']}', [sheet]).isNotEmpty) doc,
        ]
        case final used when used.isNotEmpty)
      entry.key: used,
};
