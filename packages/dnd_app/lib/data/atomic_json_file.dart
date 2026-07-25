import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

File _temporaryFor(File destination, String suffix) => File(
  p.join(
    destination.parent.path,
    '.${p.basename(destination.path)}.$suffix.tmp',
  ),
);

/// Escribe JSON mediante un archivo temporal ubicado junto al destino y un
/// renombrado final. Así un cierre durante la escritura no deja JSON parcial.
Future<void> writeJsonAtomic(
  File destination,
  Object? value, {
  bool pretty = true,
}) async {
  await destination.parent.create(recursive: true);
  final suffix =
      '$pid-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
  final temporary = _temporaryFor(destination, suffix);
  final encoded = pretty
      ? const JsonEncoder.withIndent('  ').convert(value)
      : jsonEncode(value);

  try {
    await temporary.writeAsString(encoded, flush: true);
    await temporary.rename(destination.path);
  } finally {
    if (await temporary.exists()) {
      await temporary.delete();
    }
  }
}

/// Variante atómica para bytes, usada al migrar archivos existentes sin
/// exponer un destino parcialmente copiado.
Future<void> writeBytesAtomic(File destination, List<int> bytes) async {
  await destination.parent.create(recursive: true);
  final suffix =
      '$pid-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
  final temporary = _temporaryFor(destination, suffix);
  try {
    await temporary.writeAsBytes(bytes, flush: true);
    await temporary.rename(destination.path);
  } finally {
    if (await temporary.exists()) await temporary.delete();
  }
}

/// Prepara todos los JSON antes de reemplazar ningún destino. Durante el commit
/// conserva copias de los archivos anteriores y revierte el lote si falla uno
/// de los renombrados.
Future<void> writeJsonBatchAtomic(Map<File, Object?> values) async {
  final prepared = <_PreparedJsonWrite>[];
  var committed = false;
  try {
    var index = 0;
    for (final entry in values.entries) {
      await entry.key.parent.create(recursive: true);
      final suffix =
          '$pid-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-$index';
      final temporary = _temporaryFor(entry.key, suffix);
      final backup = File('${entry.key.path}.$suffix.bak');
      await temporary.writeAsString(
        const JsonEncoder.withIndent('  ').convert(entry.value),
        flush: true,
      );
      prepared.add(_PreparedJsonWrite(entry.key, temporary, backup));
      index++;
    }

    for (final item in prepared) {
      if (await item.destination.exists()) {
        await item.destination.rename(item.backup.path);
        item.hasBackup = true;
      }
      await item.temporary.rename(item.destination.path);
      item.installed = true;
    }
    committed = true;
  } catch (error, stackTrace) {
    for (final item in prepared.reversed) {
      try {
        if (item.installed && await item.destination.exists()) {
          await item.destination.delete();
        }
        if (item.hasBackup && await item.backup.exists()) {
          await item.backup.rename(item.destination.path);
        }
      } catch (_) {
        // Se preserva el backup para recuperación manual.
      }
    }
    Error.throwWithStackTrace(error, stackTrace);
  } finally {
    for (final item in prepared) {
      try {
        if (await item.temporary.exists()) await item.temporary.delete();
        if (committed && await item.backup.exists()) await item.backup.delete();
      } catch (_) {
        // Un temporal o backup huérfano es preferible a fallar tras el commit.
      }
    }
  }
}

class _PreparedJsonWrite {
  final File destination;
  final File temporary;
  final File backup;
  bool hasBackup = false;
  bool installed = false;

  _PreparedJsonWrite(this.destination, this.temporary, this.backup);
}
