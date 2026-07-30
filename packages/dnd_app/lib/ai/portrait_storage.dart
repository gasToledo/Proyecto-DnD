import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../data/app_paths.dart';

/// Guarda una imagen generada en disco y devuelve su ruta.
Future<String> savePortrait({
  required String portraitsRoot,
  required String characterId,
  required Uint8List bytes,
}) async {
  final safeCharacterId = requireSafePathSegment(
    characterId,
    label: 'id de personaje',
  );
  final dir = Directory(p.join(portraitsRoot, safeCharacterId));
  await dir.create(recursive: true);
  final file = File(
    p.join(dir.path, '${DateTime.now().microsecondsSinceEpoch}.png'),
  );
  await file.writeAsBytes(bytes);
  return file.path;
}
