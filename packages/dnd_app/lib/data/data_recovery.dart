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
