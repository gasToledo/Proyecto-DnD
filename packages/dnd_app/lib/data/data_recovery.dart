import 'dart:io';

import 'package:path/path.dart' as p;

import 'app_paths.dart';

class DataRecoveryIssue {
  final String originalPath;
  final String recoveryPath;
  final String error;

  const DataRecoveryIssue({
    required this.originalPath,
    required this.recoveryPath,
    required this.error,
  });

  bool get wasMoved => originalPath != recoveryPath;
}

class DataMigrationBackup {
  final String originalPath;
  final String backupPath;
  final int fromVersion;
  final int toVersion;

  const DataMigrationBackup({
    required this.originalPath,
    required this.backupPath,
    required this.fromVersion,
    required this.toVersion,
  });
}

/// Conserva el documento exacto anterior a una migración automática. La copia
/// vive separada de los archivos corruptos porque sigue siendo válida para la
/// versión de la aplicación que la creó.
Future<DataMigrationBackup> backupBeforeMigration(
  File source, {
  required int fromVersion,
  required int toVersion,
  String? dataRoot,
}) async {
  final backupDir = Directory(
    p.join(fichasDir('recovery', dataRoot), 'migrations'),
  );
  await backupDir.create(recursive: true);
  final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
  final backup = File(
    p.join(
      backupDir.path,
      '${p.basenameWithoutExtension(source.path)}-v$fromVersion-a-v$toVersion-'
      '$stamp${p.extension(source.path)}',
    ),
  );
  await source.copy(backup.path);
  return DataMigrationBackup(
    originalPath: source.path,
    backupPath: backup.path,
    fromVersion: fromVersion,
    toVersion: toVersion,
  );
}

/// Aparta un archivo ilegible sin borrarlo para que la aplicación pueda
/// continuar y el usuario tenga una copia disponible para recuperación manual.
Future<DataRecoveryIssue> recoverCorruptFile(
  File source,
  Object error, {
  String? dataRoot,
}) async {
  final recoveryDir = Directory(fichasDir('recovery', dataRoot));
  await recoveryDir.create(recursive: true);
  final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
  final recovered = File(
    p.join(
      recoveryDir.path,
      '${p.basenameWithoutExtension(source.path)}-$stamp${p.extension(source.path)}',
    ),
  );

  try {
    await source.rename(recovered.path);
    return DataRecoveryIssue(
      originalPath: source.path,
      recoveryPath: recovered.path,
      error: error.toString(),
    );
  } catch (moveError) {
    return DataRecoveryIssue(
      originalPath: source.path,
      recoveryPath: source.path,
      error: '$error; no se pudo apartar: $moveError',
    );
  }
}
