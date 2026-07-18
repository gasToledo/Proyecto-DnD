import 'dart:io';

import 'package:path/path.dart' as p;

/// Raíz del hogar del usuario (Windows/Unix), con degradación segura.
String homeRoot() {
  final env = Platform.environment;
  return env['USERPROFILE'] ??
      env['HOME'] ??
      env['LOCALAPPDATA'] ??
      Directory.systemTemp.path;
}

/// Carpeta base de la app (`<home>/FichasDnD`), opcionalmente con subcarpeta.
/// Usa el separador correcto de la plataforma vía package:path.
String fichasDir([String? sub]) => sub == null
    ? p.join(homeRoot(), 'FichasDnD')
    : p.join(homeRoot(), 'FichasDnD', sub);
