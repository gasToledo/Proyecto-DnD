import 'dart:io';

import 'package:path/path.dart' as p;

/// Raíz canónica de datos de la aplicación.
///
/// En Windows usamos el perfil visible del usuario para mantener toda la
/// carpeta `FichasDnD` junta y fácil de respaldar. Los stores aceptan una raíz
/// inyectada en tests.
String dataHomeRoot() {
  final env = Platform.environment;
  return env['USERPROFILE'] ??
      env['HOME'] ??
      env['LOCALAPPDATA'] ??
      Directory.systemTemp.path;
}

/// Carpeta base de la app (`<home>/FichasDnD`), opcionalmente con subcarpeta.
/// Usa el separador correcto de la plataforma vía package:path.
String fichasDir([String? sub, String? rootOverride]) {
  final root = rootOverride ?? dataHomeRoot();
  return sub == null
      ? p.join(root, 'FichasDnD')
      : p.join(root, 'FichasDnD', sub);
}

/// Ubicación usada por versiones anteriores para los personajes en Windows.
/// Solo se conserva para migrarlos una vez a la raíz canónica.
String? legacyCharactersDir() {
  if (!Platform.isWindows) return null;
  final local = Platform.environment['LOCALAPPDATA'];
  if (local == null) return null;
  final legacy = p.join(local, 'FichasDnD', 'characters');
  final canonical = fichasDir('characters');
  return p.equals(p.normalize(legacy), p.normalize(canonical)) ? null : legacy;
}

/// Verifica identificadores que se usan como nombre de archivo o directorio.
/// Los imports son datos externos: no deben poder escapar de `FichasDnD`.
String requireSafePathSegment(String value, {String label = 'identificador'}) {
  if (value.isEmpty ||
      value == '.' ||
      value == '..' ||
      !RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(value)) {
    throw FormatException('El $label contiene caracteres no permitidos.');
  }
  return value;
}
