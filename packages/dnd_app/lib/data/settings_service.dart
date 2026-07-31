import 'dart:convert';
import 'dart:io';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:path/path.dart' as p;

import '../ai/portrait_provider.dart' show retiredProviderIds;
import 'app_paths.dart';
import 'atomic_json_file.dart';
import 'data_recovery.dart';

/// Ajustes de la app persistidos localmente. Por ahora, solo la configuración
/// de generación de imágenes. Se guarda en texto plano en el equipo del usuario
/// (app personal); Claude nunca la ve ni la solicita.
class AppSettings {
  static const int currentSchemaVersion = 4;

  /// Proveedor de imágenes elegido:
  /// 'pollinations' | 'azure-gpt-image' | 'azure'.
  String imageProvider;

  /// Key del recurso de Azure AI Foundry que sirve Flux.
  String azureApiKey;

  /// Key del recurso de Azure que sirve gpt-image-2. Es otro recurso, con su
  /// propia key: no se pueden compartir.
  String azureOpenAiApiKey;

  AppSettings({
    this.imageProvider = 'pollinations',
    this.azureApiKey = '',
    this.azureOpenAiApiKey = '',
  });

  /// La key correspondiente al proveedor indicado (o '' si no aplica).
  String keyFor(String providerId) => switch (providerId) {
    'azure' => azureApiKey,
    'azure-gpt-image' => azureOpenAiApiKey,
    _ => '',
  };

  Map<String, dynamic> toJson() => {
    'schemaVersion': currentSchemaVersion,
    'preferences': {'imageProvider': imageProvider},
    'credentials': {
      'azureApiKey': azureApiKey,
      'azureOpenAiApiKey': azureOpenAiApiKey,
    },
  };

  /// Preferencias aptas para un respaldo compartible. Las credenciales quedan
  /// siempre en el equipo de origen.
  Map<String, dynamic> toPortableJson() => {'imageProvider': imageProvider};

  static int schemaVersionOf(Map<String, dynamic> json) {
    final value = json['schemaVersion'] ?? 1;
    if (value is! int || value < 1) {
      throw const FormatException(
        'La versión de los ajustes debe ser un entero positivo.',
      );
    }
    return value;
  }

  static Map<String, dynamic> migrateJson(Map<String, dynamic> source) {
    var migrated = Map<String, dynamic>.from(source);
    var version = schemaVersionOf(migrated);
    if (version > currentSchemaVersion) {
      throw UnsupportedDataVersionException(
        dataType: 'ajustes',
        found: version,
        supported: currentSchemaVersion,
      );
    }

    while (version < currentSchemaVersion) {
      switch (version) {
        case 1:
          migrated = {
            'schemaVersion': 2,
            'preferences': {
              'imageProvider':
                  migrated['imageProvider'] as String? ?? 'pollinations',
              'huggingFaceModel': migrated['huggingFaceModel'] as String? ?? '',
            },
            'credentials': {
              'geminiApiKey': migrated['geminiApiKey'] as String? ?? '',
              'huggingFaceToken': migrated['huggingFaceToken'] as String? ?? '',
            },
          };
          version = 2;
        case 2:
          final credentials =
              (migrated['credentials'] as Map?)?.cast<String, dynamic>() ??
              const {};
          migrated = {
            'schemaVersion': 3,
            'preferences': migrated['preferences'],
            'credentials': {...credentials, 'azureApiKey': ''},
          };
          version = 3;
        case 3:
          // Salen Hugging Face y Gemini, entra gpt-image-2. Sus credenciales se
          // borran del archivo en vez de quedar huérfanas, y un proveedor
          // retirado vuelve al que no necesita key.
          final preferences =
              (migrated['preferences'] as Map?)?.cast<String, dynamic>() ??
              const {};
          final credentials =
              (migrated['credentials'] as Map?)?.cast<String, dynamic>() ??
              const {};
          final provider = preferences['imageProvider'] as String?;
          migrated = {
            'schemaVersion': 4,
            'preferences': {
              'imageProvider': retiredProviderIds.contains(provider)
                  ? 'pollinations'
                  : provider ?? 'pollinations',
            },
            'credentials': {
              'azureApiKey': credentials['azureApiKey'] as String? ?? '',
              'azureOpenAiApiKey': '',
            },
          };
          version = 4;
      }
    }
    return migrated;
  }

  factory AppSettings.fromJson(Map<String, dynamic> source) {
    final j = migrateJson(source);
    final preferences =
        (j['preferences'] as Map?)?.cast<String, dynamic>() ?? const {};
    final credentials =
        (j['credentials'] as Map?)?.cast<String, dynamic>() ?? const {};
    return AppSettings(
      imageProvider: preferences['imageProvider'] as String? ?? 'pollinations',
      azureApiKey: credentials['azureApiKey'] as String? ?? '',
      azureOpenAiApiKey: credentials['azureOpenAiApiKey'] as String? ?? '',
    );
  }
}

class SettingsService {
  final String? dataRoot;
  final List<DataRecoveryIssue> recoveryIssues = [];
  final List<DataMigrationBackup> migrationBackups = [];
  bool _protectFutureVersion = false;

  SettingsService({this.dataRoot});

  File get _file => File(p.join(fichasDir(null, dataRoot), 'settings.json'));

  Future<AppSettings> load() async {
    recoveryIssues.clear();
    migrationBackups.clear();
    _protectFutureVersion = false;
    final f = _file;
    if (!await f.exists()) return AppSettings();
    Map<String, dynamic> migrated;
    AppSettings settings;
    int originalVersion;
    try {
      final decoded = jsonDecode(await f.readAsString());
      final json = (decoded as Map).cast<String, dynamic>();
      originalVersion = AppSettings.schemaVersionOf(json);
      migrated = AppSettings.migrateJson(json);
      settings = AppSettings.fromJson(migrated);
    } on UnsupportedDataVersionException catch (error) {
      _protectFutureVersion = true;
      recoveryIssues.add(
        DataRecoveryIssue(
          originalPath: f.path,
          recoveryPath: f.path,
          error: error.toString(),
        ),
      );
      return AppSettings();
    } catch (error) {
      if (await f.exists()) {
        recoveryIssues.add(
          await recoverCorruptFile(f, error, dataRoot: dataRoot),
        );
      }
      return AppSettings();
    }

    if (originalVersion < AppSettings.currentSchemaVersion) {
      try {
        final backup = await backupBeforeMigration(
          f,
          fromVersion: originalVersion,
          toVersion: AppSettings.currentSchemaVersion,
          dataRoot: dataRoot,
        );
        await writeJsonAtomic(f, migrated, pretty: false);
        migrationBackups.add(backup);
      } catch (error) {
        recoveryIssues.add(
          DataRecoveryIssue(
            originalPath: f.path,
            recoveryPath: f.path,
            error: 'No se pudo guardar la migración: $error',
          ),
        );
      }
    }
    return settings;
  }

  Future<void> save(AppSettings settings) async {
    if (_protectFutureVersion && await _file.exists()) {
      throw StateError(
        'No se sobrescribieron los ajustes porque usan una versión futura.',
      );
    }
    await writeJsonAtomic(_file, settings.toJson(), pretty: false);
  }

  /// Aplica únicamente preferencias portables y conserva las credenciales
  /// locales existentes.
  Future<void> restorePortable(Map<String, dynamic> preferences) async {
    final current = await load();
    final provider = preferences['imageProvider'];
    // Un respaldo viejo puede traer un proveedor ya retirado: se ignora en vez
    // de dejar los ajustes apuntando a algo que no existe.
    if (provider is String &&
        const {'pollinations', 'azure', 'azure-gpt-image'}.contains(provider)) {
      current.imageProvider = provider;
    }
    await save(current);
  }
}
