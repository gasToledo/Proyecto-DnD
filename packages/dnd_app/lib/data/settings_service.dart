import 'dart:convert';
import 'dart:io';

import 'package:dnd_engine/dnd_engine.dart';
import 'package:path/path.dart' as p;

import 'app_paths.dart';
import 'atomic_json_file.dart';
import 'data_recovery.dart';

/// Ajustes de la app persistidos localmente. Por ahora, solo la API key de
/// generación de imágenes. Se guarda en texto plano en el equipo del usuario
/// (app personal); Claude nunca la ve ni la solicita.
/// Modelo por defecto de Hugging Face servido hoy por el proveedor gratuito
/// `hf-inference` (el catálogo gratuito cambia seguido; por eso es editable).
const defaultHuggingFaceModel =
    'stabilityai/stable-diffusion-3-medium-diffusers';

class AppSettings {
  static const int currentSchemaVersion = 2;

  /// Proveedor de imágenes elegido: 'pollinations' | 'huggingface' | 'gemini'.
  String imageProvider;
  String geminiApiKey;
  String huggingFaceToken;
  String huggingFaceModel;

  AppSettings({
    this.imageProvider = 'pollinations',
    this.geminiApiKey = '',
    this.huggingFaceToken = '',
    this.huggingFaceModel = defaultHuggingFaceModel,
  });

  /// La key correspondiente al proveedor indicado (o '' si no aplica).
  String keyFor(String providerId) => switch (providerId) {
    'gemini' => geminiApiKey,
    'huggingface' => huggingFaceToken,
    _ => '',
  };

  Map<String, dynamic> toJson() => {
    'schemaVersion': currentSchemaVersion,
    'preferences': {
      'imageProvider': imageProvider,
      'huggingFaceModel': huggingFaceModel,
    },
    'credentials': {
      'geminiApiKey': geminiApiKey,
      'huggingFaceToken': huggingFaceToken,
    },
  };

  /// Preferencias aptas para un respaldo compartible. Las credenciales quedan
  /// siempre en el equipo de origen.
  Map<String, dynamic> toPortableJson() => {
    'imageProvider': imageProvider,
    'huggingFaceModel': huggingFaceModel,
  };

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
              'huggingFaceModel':
                  migrated['huggingFaceModel'] as String? ??
                  defaultHuggingFaceModel,
            },
            'credentials': {
              'geminiApiKey': migrated['geminiApiKey'] as String? ?? '',
              'huggingFaceToken': migrated['huggingFaceToken'] as String? ?? '',
            },
          };
          version = 2;
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
      geminiApiKey: credentials['geminiApiKey'] as String? ?? '',
      huggingFaceToken: credentials['huggingFaceToken'] as String? ?? '',
      huggingFaceModel:
          (preferences['huggingFaceModel'] as String?)?.trim().isNotEmpty ==
              true
          ? preferences['huggingFaceModel'] as String
          : defaultHuggingFaceModel,
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
    final model = preferences['huggingFaceModel'];
    if (provider is String &&
        const {'pollinations', 'huggingface', 'gemini'}.contains(provider)) {
      current.imageProvider = provider;
    }
    if (model is String && model.trim().isNotEmpty) {
      current.huggingFaceModel = model.trim();
    }
    await save(current);
  }
}
