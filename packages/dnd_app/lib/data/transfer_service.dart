import 'dart:convert';
import 'dart:typed_data';

import 'package:dnd_engine/dnd_engine.dart';

import '../api/api_client.dart';
import 'backup_bundle.dart';

/// Construye los archivos de exportación en memoria, para que la UI los
/// entregue como descarga del navegador (ver capacidad `web-client`). A
/// diferencia de la versión de escritorio, no escribe a disco ni sabe nada
/// de una carpeta de exportaciones: cada método devuelve bytes y un nombre
/// de archivo sugerido.
class TransferService {
  static const int formatVersion = 1;

  final ApiClient api;

  const TransferService(this.api);

  static String _safe(String s) =>
      s.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

  static String _timestamp() =>
      DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;

  /// Exporta un personaje. Los retratos se piden al servidor por su clave
  /// (autenticado por la sesión de la cuenta), no se leen de disco.
  Future<Uint8List> exportCharacter(Character c) => BackupBundleCodec.encode(
    scope: BackupScope.character,
    characters: [c],
    readPortrait: api.fetchPortraitBytes,
  );

  String characterExportFileName(Character c) =>
      '${_safe(c.name)}-${_safe(c.id)}.zip';

  /// Exporta un respaldo completo.
  Future<Uint8List> exportBackup(
    List<Character> all, {
    Map<String, List<Map<String, dynamic>>>? homebrew,
    Map<String, dynamic>? preferences,
  }) => BackupBundleCodec.encode(
    scope: BackupScope.full,
    characters: all,
    homebrew: homebrew,
    preferences: preferences,
    readPortrait: api.fetchPortraitBytes,
  );

  String backupFileName() => 'backup-${_timestamp()}.zip';

  /// Todo el contenido homebrew (listas JSON por tipo) envuelto en el
  /// formato `dnd_homebrew`, como bytes UTF-8 listos para descargar.
  Uint8List exportHomebrew(Map<String, List<Map<String, dynamic>>> content) {
    final envelope = {
      'type': 'dnd_homebrew',
      'formatVersion': formatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'content': content,
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(envelope)));
  }

  String homebrewExportFileName() => 'homebrew-${_timestamp()}.json';

  /// Parsea un export de homebrew (`dnd_homebrew`) a listas JSON por tipo.
  /// Lógica pura (testeable): mismo formato liviano de siempre, sin relación
  /// con el respaldo ZIP principal (ver capacidad `account-data-import`, que
  /// cubre ese otro flujo vía `POST /api/import`).
  static Map<String, List<Map<String, dynamic>>> parseHomebrewImport(
    String jsonText,
  ) {
    final data = jsonDecode(jsonText);
    if (data is Map<String, dynamic> && data['type'] == 'dnd_homebrew') {
      final version = data['formatVersion'];
      if (version is! int || version < 1) {
        throw const FormatException(
          'La versión de la exportación Homebrew debe ser un entero positivo.',
        );
      }
      if (version > formatVersion) {
        throw UnsupportedDataVersionException(
          dataType: 'exportación Homebrew',
          found: version,
          supported: formatVersion,
        );
      }
      final content = (data['content'] as Map?)?.cast<String, dynamic>() ?? {};
      return {
        for (final key in const [
          'weapons',
          'armor',
          'feats',
          'races',
          'backgrounds',
          'spells',
        ])
          key: ((content[key] as List?) ?? const [])
              .map((e) => (e as Map).cast<String, dynamic>())
              .toList(),
      };
    }
    throw const FormatException(
      'El archivo no es un pack de contenido homebrew válido.',
    );
  }
}
