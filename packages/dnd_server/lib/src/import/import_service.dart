import 'package:dnd_engine/dnd_engine.dart';
import 'package:postgres/postgres.dart';

import '../portraits/portrait_blob_store.dart';
import '../repositories/character_repository.dart';
import '../repositories/homebrew_repository.dart';
import '../repositories/id_allocation.dart';
import '../repositories/settings_repository.dart';
import 'backup_bundle.dart';

class ImportResult {
  final int charactersImported;
  final int portraitsImported;

  const ImportResult({
    required this.charactersImported,
    required this.portraitsImported,
  });
}

/// Resultado de resolver ids y guardar los retratos de un [BackupBundle]: la
/// parte de la importación que no toca la base de datos, y por eso se puede
/// probar sin una conexión real.
class PreparedImport {
  final List<Character> characters;
  final int portraitsImported;

  const PreparedImport({
    required this.characters,
    required this.portraitsImported,
  });
}

/// Resuelve los ids de [bundle] contra [existingIds] y guarda sus retratos.
///
/// Un id que ya existe en la cuenta se resuelve a uno libre, igual que en la
/// aplicación de escritorio (`prepareCharacterImport`): nunca se sobrescribe
/// un personaje existente, así importar el mismo respaldo dos veces solo crea
/// una segunda copia en vez de corromper o eliminar la primera. Los retratos
/// se guardan bajo el id efectivo (el reasignado, si lo hubo) antes de armar
/// el documento, para que sus claves ya vengan resueltas.
Future<PreparedImport> prepareImport({
  required PortraitBlobStore portraits,
  required String userId,
  required BackupBundle bundle,
  required Set<String> existingIds,
}) async {
  final reservedIds = Set<String>.of(existingIds);
  final preparedCharacters = <Character>[];
  var portraitsImported = 0;

  for (var i = 0; i < bundle.characters.length; i++) {
    final entry = bundle.characters[i];
    final id = resolveStorageId(
      requestedId: entry.character.id,
      existingIds: reservedIds,
      fallbackId: () => '${DateTime.now().microsecondsSinceEpoch}-$i',
    );
    reservedIds.add(id);

    final portraitKeys = <String>[];
    for (final portrait in entry.portraits) {
      final key = await portraits.save(
        userId: userId,
        characterId: id,
        bytes: portrait.bytes,
      );
      portraitKeys.add(key);
      portraitsImported++;
    }

    var character = entry.character;
    if (character.id != id) {
      character = Character.fromJson(character.toJson()..['id'] = id);
    }
    preparedCharacters.add(character.copyWith(portraitPaths: portraitKeys));
  }

  return PreparedImport(
    characters: preparedCharacters,
    portraitsImported: portraitsImported,
  );
}

/// Importa un [BackupBundle] ya decodificado y validado (una versión de
/// formato futura ya se rechazó en `BackupBundleCodec.decode`, antes de
/// llegar acá) para la cuenta [userId].
///
/// Los personajes, el homebrew y las preferencias se escriben en una única
/// transacción de Postgres: si cualquiera falla, ninguno de los tres queda
/// modificado. Los retratos viven en un volumen aparte (ver capacidad
/// `portrait-storage`) y por eso no pueden compartir esa transacción; un
/// fallo de disco a mitad de la subida puede dejar blobs huérfanos sin
/// referenciar, que es la misma política de retención pendiente que ya
/// declara `design.md` como fuera de alcance.
///
/// La garantía de `Pool.runTx` requiere una base de datos viva para probarse
/// en los hechos. La resolución de ids y el guardado de retratos sí tienen
/// prueba unitaria, en [prepareImport].
Future<ImportResult> importBackup({
  required Pool pool,
  required PortraitBlobStore portraits,
  required String userId,
  required BackupBundle bundle,
}) async {
  final existingIds = await pool.run(
    (session) => PostgresCharacterRepository(session).existingIds(userId),
  );
  final prepared = await prepareImport(
    portraits: portraits,
    userId: userId,
    bundle: bundle,
    existingIds: existingIds,
  );

  await pool.runTx((session) async {
    final characterRepo = PostgresCharacterRepository(session);
    for (final character in prepared.characters) {
      await characterRepo.upsert(userId, character);
    }

    final homebrew = bundle.homebrew;
    if (homebrew != null) {
      final homebrewRepo = PostgresHomebrewRepository(session);
      for (final category in homebrew.entries) {
        for (final document in category.value) {
          final id = document['id'];
          if (id is String) {
            await homebrewRepo.upsert(userId, category.key, id, document);
          }
        }
      }
    }

    final preferences = bundle.preferences;
    if (preferences != null) {
      final settingsRepo = PostgresSettingsRepository(session);
      final current = await settingsRepo.find(userId) ?? const {};
      await settingsRepo.save(userId, {...current, ...preferences});
    }
  });

  return ImportResult(
    charactersImported: prepared.characters.length,
    portraitsImported: prepared.portraitsImported,
  );
}
